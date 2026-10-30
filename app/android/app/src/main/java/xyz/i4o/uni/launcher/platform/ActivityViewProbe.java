package xyz.i4o.uni.launcher.platform;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.AttributeSet;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

/**
 * ActivityView 版地图嵌入探针（spike 2）。
 *
 * `android.app.ActivityView` 是隐藏 API（编译 SDK 里不可见），所以这里全程反射：
 * 构造 → addView → 延迟调 startActivity（ActivityView 在 attach 之后才创建虚拟屏）。
 *
 * 只验证帧率，不做圆角遮罩、不做翻页定格。
 * 只在 `--dart-define=MAP_ACTIVITYVIEW=true` 的构建里被地图卡使用。
 */
public final class ActivityViewProbe implements PlatformView {

    public static final String VIEW_TYPE = "uni.map.activityview";
    private static final String TAG = "UniActivityView";

    public static final class Factory extends PlatformViewFactory {
        private final Activity activity;
        public Factory(Activity activity) {
            super(StandardMessageCodec.INSTANCE);
            this.activity = activity;
        }
        @Override public PlatformView create(Context context, int viewId, Object args) {
            return new ActivityViewProbe(activity, args);
        }
    }

    private final Activity activity;
    private final FrameLayout container;
    private final String pkg;
    private View activityView;
    private boolean launched;

    @SuppressWarnings("unchecked")
    public ActivityViewProbe(Activity activity, Object args) {
        this.activity = activity;
        Map<Object, Object> params = args instanceof Map ? (Map<Object, Object>) args : new HashMap<>();
        this.pkg = String.valueOf(params.get("package"));
        container = new FrameLayout(activity);
        try {
            Class<?> cls = Class.forName("android.app.ActivityView");
            activityView = construct(cls);
            if (activityView == null) {
                android.util.Log.w(TAG, "ActivityView construct failed");
                return;
            }
            container.addView(activityView, new FrameLayout.LayoutParams(-1, -1));
            android.util.Log.i(TAG, "ActivityView created: " + activityView.getClass().getName());
            // ActivityView 在 attach 之后才创建虚拟屏；给它时间再启动。
            container.postDelayed(this::launch, 1200);
        } catch (Throwable error) {
            android.util.Log.w(TAG, "ActivityView unavailable", error);
        }
    }

    private View construct(Class<?> cls) {
        try {
            Constructor<?> one = cls.getConstructor(Context.class);
            one.setAccessible(true);
            return (View) one.newInstance(activity);
        } catch (Throwable ignored) { }
        try {
            Constructor<?> three = cls.getConstructor(Context.class, AttributeSet.class, int.class);
            three.setAccessible(true);
            return (View) three.newInstance(activity, null, 0);
        } catch (Throwable ignored) { }
        return null;
    }

    private void launch() {
        if (launched || activityView == null) return;
        launched = true;
        try {
            Intent intent = activity.getPackageManager().getLaunchIntentForPackage(pkg);
            if (intent == null) {
                android.util.Log.w(TAG, "no launch intent for " + pkg);
                return;
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            Method start = activityView.getClass().getMethod("startActivity", Intent.class);
            start.setAccessible(true);
            start.invoke(activityView, intent);
            android.util.Log.i(TAG, "started " + pkg + " inside ActivityView");
        } catch (Throwable error) {
            android.util.Log.w(TAG, "startActivity failed", error);
        }
    }

    @Override public View getView() { return container; }

    @Override public void dispose() {
        try {
            if (container.getChildCount() > 0) {
                View child = container.getChildAt(0);
                container.removeView(child);
                Method release = child.getClass().getMethod("release");
                release.setAccessible(true);
                release.invoke(child);
            }
        } catch (Throwable ignored) { }
    }
}
