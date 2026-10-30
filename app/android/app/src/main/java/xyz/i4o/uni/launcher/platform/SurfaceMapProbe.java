package xyz.i4o.uni.launcher.platform;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ActivityOptions;
import android.content.ComponentName;
import android.content.Intent;
import android.graphics.Rect;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.os.Handler;
import android.os.Looper;
import android.view.InputEvent;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.FrameLayout;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * SurfaceView 版地图嵌入探针（补齐版）。
 *
 * 在 spike 1 的基础上补齐了原生桌面（君君）在 ActivityView 之外做的五件事：
 *   1. 虚拟屏与 Surface 尺寸严格相等（setFixedSize + resize + resizeTask 修几何 + 重试）
 *   2. 图层 z 序显式压回普通层（setZOrderOnTop/MediaOverlay 都是 false）
 *   3. 触摸走 injectInputEvent + setDisplayId，而不是框架转发
 *   4. resize 期间用遮罩盖住，避免 resize 风暴露黑帧
 *   5. 启动 flag 用 NEW_TASK|RESET_TASK_IF_NEEDED、无转场动画，带看门狗重建
 *
 * 只在 `--dart-define=MAP_SURFACE=true` 的构建里被地图卡使用。
 */
public final class SurfaceMapProbe implements PlatformView {

    public static final String VIEW_TYPE = "uni.map.surface";
    private static final String TAG = "UniSurfaceMap";
    private static final long WATCHDOG_MS = 1000;
    private static final int MAX_LAUNCH = 3;

    public static final class Factory extends PlatformViewFactory {
        private final Activity activity;
        public Factory(Activity activity) {
            super(StandardMessageCodec.INSTANCE);
            this.activity = activity;
        }
        @Override public PlatformView create(android.content.Context context, int viewId, Object args) {
            return new SurfaceMapProbe(activity, args);
        }
    }

    private final Activity activity;
    private final FrameLayout container;
    private final SurfaceView surfaceView;
    private final View resizeCover;
    private final String pkg;
    private final Handler main = new Handler(Looper.getMainLooper());

    private VirtualDisplay display;
    private Surface surface;
    private Object forwarder;
    private Method forwardEvent;
    private int width, height, dpi;
    private int launchCount, taskMoves, geometryAttempts;
    private boolean launched, released;
    private Surface pending;
    private int misses;

    @SuppressWarnings("unchecked")
    public SurfaceMapProbe(Activity activity, Object args) {
        this.activity = activity;
        Map<Object, Object> params = args instanceof Map ? (Map<Object, Object>) args : new HashMap<>();
        this.pkg = String.valueOf(params.get("package"));
        this.width = Math.max(320, intOf(params.get("width"), 1229));
        this.height = Math.max(240, intOf(params.get("height"), 814));
        this.dpi = Math.max(72, intOf(params.get("density"), 160));

        container = new FrameLayout(activity);
        surfaceView = new SurfaceView(activity);
        // ② z 序：压回普通层
        surfaceView.setZOrderOnTop(false);
        surfaceView.setZOrderMediaOverlay(false);
                container.addView(surfaceView, new FrameLayout.LayoutParams(-1, -1));

        // ④ resize 遮罩
        resizeCover = new View(activity);
        resizeCover.setBackgroundColor(0xFF101418);
        resizeCover.setVisibility(View.GONE);
        container.addView(resizeCover, new FrameLayout.LayoutParams(-1, -1));

        surfaceView.getHolder().addCallback(new SurfaceHolder.Callback() {
            @Override public void surfaceCreated(SurfaceHolder holder) { pending = holder.getSurface(); }
            @Override public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
                if (w <= 0 || h <= 0) return;
                if (display == null) {
                    width = w;
                    height = h;
                    createDisplay(holder.getSurface());
                    return;
                }
                if (w == width && h == height) return;
                width = w;
                height = h;
                showCover();
                try { display.resize(w, h, dpi); } catch (Throwable ignored) { }
                repairTaskGeometry();
            }
            @Override public void surfaceDestroyed(SurfaceHolder holder) { releaseDisplay(); }
        });
        surfaceView.setOnTouchListener((v, event) -> { inject(event); return true; });
    }

    private static int intOf(Object value, int fallback) {
        if (value instanceof Number) {
            double v = ((Number) value).doubleValue();
            if (v > 0) return (int) Math.round(v);
        }
        return fallback;
    }

    private void showCover() {
        resizeCover.setVisibility(View.VISIBLE);
        main.removeCallbacks(this::hideCover);
        main.postDelayed(this::hideCover, 160);
    }

    private void hideCover() {
        if (!released) resizeCover.setVisibility(View.GONE);
    }

    private void createDisplay(Surface output) {
        if (display != null || output == null || !output.isValid()) return;
        try {
            DisplayManager manager = (DisplayManager) activity.getSystemService(Activity.DISPLAY_SERVICE);
            display = manager.createVirtualDisplay("UNI SurfaceMap", width, height, dpi, output,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC
                            | DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY);
            surface = output;
            int displayId = display.getDisplay().getDisplayId();
            try {
                Object wm = Class.forName("android.view.WindowManagerGlobal")
                        .getMethod("getWindowManagerService").invoke(null);
                Method override = wm.getClass().getMethod("dontOverrideDisplayInfo", int.class);
                override.setAccessible(true);
                override.invoke(wm, displayId);
            } catch (Throwable ignored) { }
            // ③ 触摸：非 system uid 用不了 injectInputEvent（要 INJECT_EVENTS），
            // 改用框架的 InputForwarder——这也正是正式方案用的通道。
            try {
                Object input = Class.forName("android.hardware.input.InputManager")
                        .getMethod("getInstance").invoke(null);
                Method create = input.getClass().getMethod("createInputForwarder", int.class);
                create.setAccessible(true);
                forwarder = create.invoke(input, displayId);
                forwardEvent = forwarder.getClass().getMethod("forwardEvent", InputEvent.class);
                forwardEvent.setAccessible(true);
            } catch (Throwable error) {
                android.util.Log.w(TAG, "input forwarder unavailable", error);
            }
            android.util.Log.i(TAG, "display=" + displayId + " " + width + "x" + height + "@" + dpi);
            launch(displayId);
            main.postDelayed(watchdog, WATCHDOG_MS);
        } catch (Throwable error) {
            android.util.Log.w(TAG, "createDisplay failed", error);
        }
    }

    private void launch(int displayId) {
        if (released || launchCount >= MAX_LAUNCH) return;
        try {
            Intent intent = activity.getPackageManager().getLaunchIntentForPackage(pkg);
            if (intent == null) {
                android.util.Log.w(TAG, "no launch intent for " + pkg);
                return;
            }
            // ⑤ 全屏尺寸重建 + 无转场动画
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            ActivityOptions options = ActivityOptions.makeCustomAnimation(activity, 0, 0);
            options.setLaunchDisplayId(displayId);
            activity.startActivity(intent, options.toBundle());
            launchCount++;
            launched = true;
            android.util.Log.i(TAG, "launch #" + launchCount + " -> display " + displayId);
            main.postDelayed(this::repairTaskGeometry, 400);
        } catch (Throwable error) {
            android.util.Log.w(TAG, "launch failed", error);
        }
    }

    /** 让任务本体的 bounds 与虚拟屏一致（陈旧 bounds 会让导航 App 按错尺寸排版）。 */
    private void repairTaskGeometry() {
        if (released || display == null) return;
        try {
            int displayId = display.getDisplay().getDisplayId();
            Object am = Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);
            Method all = am.getClass().getMethod("getAllStackInfos");
            all.setAccessible(true);
            for (Object stack : (List<?>) all.invoke(am)) {
                Class<?> type = stack.getClass();
                String[] names = (String[]) type.getField("taskNames").get(stack);
                if (names == null || names.length != 1 || names[0] == null
                        || !names[0].startsWith(pkg + "/")) continue;
                int stackId = type.getField("stackId").getInt(stack);
                int current = type.getField("displayId").getInt(stack);
                if (current != displayId) {
                    Method move = am.getClass().getMethod("moveStackToDisplay", int.class, int.class);
                    move.setAccessible(true);
                    move.invoke(am, stackId, displayId);
                    taskMoves++;
                    android.util.Log.i(TAG, "moved stack " + stackId + " -> display " + displayId);
                }
                // API 28 的 StackInfo 只有 taskIds（数组），没有单个 taskId。
                try {
                    int[] ids = (int[]) type.getField("taskIds").get(stack);
                    if (ids != null) {
                        Method resize = am.getClass().getMethod("resizeTask", int.class, Rect.class, int.class);
                        resize.setAccessible(true);
                        for (int taskId : ids) resize.invoke(am, taskId, null, 0);
                    }
                } catch (Throwable ignored) { }
                return;
            }
            if (++geometryAttempts < 6) main.postDelayed(this::repairTaskGeometry, 400);
        } catch (Throwable error) {
            android.util.Log.w(TAG, "repairTaskGeometry", error);
        }
    }

    /** ⑤ 看门狗：任务/画面丢失时重建，避免停在半死状态。 */
    private final Runnable watchdog = new Runnable() {
        @Override public void run() {
            if (released) return;
            try {
                if (display != null) {
                    int displayId = display.getDisplay().getDisplayId();
                    if (hasTaskOnDisplay(displayId)) {
                        misses = 0;
                    } else {
                        // 只有连续 3 次都找不到任务才重建，避免反复重启把画面搅乱。
                        repairTaskGeometry();
                        if (++misses >= 3) {
                            misses = 0;
                            launched = false;
                            launch(displayId);
                        }
                    }
                }
            } catch (Throwable ignored) { }
            main.postDelayed(this, WATCHDOG_MS);
        }
    };

    private boolean hasTaskOnDisplay(int displayId) {
        try {
            Object am = Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);
            Method all = am.getClass().getMethod("getAllStackInfos");
            all.setAccessible(true);
            for (Object stack : (List<?>) all.invoke(am)) {
                Class<?> type = stack.getClass();
                String[] names = (String[]) type.getField("taskNames").get(stack);
                if (names == null || names.length != 1 || names[0] == null
                        || !names[0].startsWith(pkg + "/")) continue;
                return type.getField("displayId").getInt(stack) == displayId;
            }
        } catch (Throwable ignored) { }
        return false;
    }

    private void inject(MotionEvent event) {
        if (released || forwardEvent == null || forwarder == null) return;
        MotionEvent copy = MotionEvent.obtain(event);
        try {
            forwardEvent.invoke(forwarder, copy);
        } catch (Throwable ignored) {
        } finally {
            copy.recycle();
        }
    }

    private void releaseDisplay() {
        main.removeCallbacks(watchdog);
        if (display != null) {
            display.release();
            display = null;
        }
        surface = null;
        launched = false;
    }

    @Override public View getView() { return container; }

    @Override public void dispose() {
        released = true;
        main.removeCallbacksAndMessages(null);
        releaseDisplay();
        container.removeAllViews();
    }
}


