package xyz.i4o.uni.launcher.voice;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONObject;

/** 桌面 App 对「独立语音模块」的唯一接线点。
 *
 * 语音已经拆成单独安装的 APK（xyz.i4o.uni.voice），桌面这边只负责三件事：
 * 把开关指令发给它、把语音需要的状态告诉它、以及替它执行车控动作。
 * 两端用同一证书签名，广播都带 signature 级权限，第三方发不进来。
 *
 *   桌面 → 语音：xyz.i4o.uni.voice.CONTROL {op=enable|disable|refresh}
 *   语音 → 桌面：VOICE_EXEC（执行车控）/ VOICE_MEDIA_QUERY（问媒体状态）/ VOICE_STATE（状态上报）
 */
public final class VoiceLink {
    private static final String TAG = "UniVoice.Link";
    public static final String VOICE_PACKAGE = "xyz.i4o.uni.voice";
    public static final String VOICE_ACTIVITY = "xyz.i4o.uni.voice.VoiceSettingsActivity";
    public static final String VOICE_PERMISSION = "xyz.i4o.uni.voice.permission.VOICE";
    public static final String LAUNCHER_PERMISSION = "xyz.i4o.uni.launcher.permission.VOICE";

    public static final String ACTION_CONTROL = "xyz.i4o.uni.voice.CONTROL";
    public static final String ACTION_EXEC = "xyz.i4o.uni.launcher.VOICE_EXEC";
    public static final String ACTION_MEDIA_QUERY = "xyz.i4o.uni.launcher.VOICE_MEDIA_QUERY";
    public static final String ACTION_STATE = "xyz.i4o.uni.launcher.VOICE_STATE";
    public static final String ACTION_STATUS = "xyz.i4o.uni.launcher.VOICE_STATUS_QUERY";

    /** 语音模块最近一次上报的状态；没装或没启动时为空。 */
    private static volatile JSONObject cached = new JSONObject();

    private VoiceLink() {}

    public static boolean installed(Context context) {
        try {
            context.getPackageManager().getPackageInfo(VOICE_PACKAGE, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    /** 开关语音：真正的开关状态由语音模块持有，这里只是发指令。 */
    /** 最近一次「桌面 → 语音」指令的结果；空串表示没问题。 */
    private static volatile String lastError = "";

    /** 发一条控制指令给语音模块。
     *
     * 两个坑必须踩过才知道：
     * 1) 语音 App 装完从没打开过时处于 stopped 状态，系统默认丢弃定向广播，
     *    必须带 FLAG_INCLUDE_STOPPED_PACKAGES，否则开关点了毫无反应。
     * 2) 有序广播能拿到「对方到底处理没有」，不用靠猜；失败原因回给界面。 */
    public static void sendControl(Context context, String op, java.util.Map<String, String> extras,
                                   Runnable onDone) {
        if (!installed(context)) {
            lastError = "语音模块未安装";
            if (onDone != null) onDone.run();
            return;
        }
        Intent intent = new Intent(ACTION_CONTROL)
                .setPackage(VOICE_PACKAGE)
                .addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                .putExtra("op", op);
        if (extras != null) {
            for (java.util.Map.Entry<String, String> e : extras.entrySet()) {
                intent.putExtra(e.getKey(), e.getValue());
            }
        }
        try {
            context.sendOrderedBroadcast(intent, VOICE_PERMISSION, new BroadcastReceiver() {
                @Override public void onReceive(Context c, Intent i) {
                    Bundle result = getResultExtras(false);
                    boolean handled = result != null && result.getBoolean("handled", false);
                    if (!handled) lastError = "语音模块没有响应（先手动打开一次「UNI 语音」）";
                    else lastError = result.getString("error", "");
                    Log.i(TAG, "control " + op + " -> handled=" + handled + " err=" + lastError);
                    if (onDone != null) onDone.run();
                }
            }, null, 0, null, null);
        } catch (SecurityException e) {
            // 两个包签名不一致时才会到这里
            lastError = "权限被拒：" + e.getMessage();
            Log.w(TAG, "control failed: " + e);
            if (onDone != null) onDone.run();
        }
    }

    public static String lastError() { return lastError; }

    public static void setEnabled(Context context, boolean on, Runnable onDone) {
        sendControl(context, on ? "enable" : "disable", null, () -> {
            // 无论成败都再要一次状态，让界面和语音模块对齐
            refresh(context);
            if (onDone != null) onDone.run();
        });
    }

    /** 打开语音模块自己的设置界面（音色/灵敏度/云端都在那边调）。 */
    public static void openSettings(Context context) {
        if (!installed(context)) return;
        try {
            context.startActivity(new Intent()
                    .setComponent(new ComponentName(VOICE_PACKAGE, VOICE_ACTIVITY))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (RuntimeException e) {
            Log.w(TAG, "open settings failed: " + e);
        }
    }

    /** 刷新：让语音模块按当前开关自行决定是否起服务。 */
    public static void refresh(Context context) {
        sendControl(context, "refresh", null, null);
    }

    /** 方控语音键：让语音模块立刻开始一次聆听（未启用时它自己会忽略）。 */
    public static void activate(Context context, String source) {
        java.util.Map<String, String> extras = new java.util.HashMap<>();
        extras.put("source", source == null ? "" : source);
        sendControl(context, "activate", extras, null);
    }

    static void onState(String json) {
        try {
            cached = json == null || json.isEmpty() ? new JSONObject() : new JSONObject(json);
        } catch (Exception e) {
            Log.w(TAG, "bad state: " + e);
        }
    }

    /** 给 Flutter 面板的 voice 块：安装状态 + 模块上报的字段。 */
    public static JSONObject snapshot(Context context) {
        JSONObject j = new JSONObject();
        try {
            j.put("installed", installed(context));
            JSONObject s = cached;
            j.put("enabled", s.optBoolean("enabled", false));
            j.put("state", s.optString("state", "idle"));
            j.put("source", s.optString("source", ""));
            j.put("wakeWord", s.optString("wakeWord", "你好 小优"));
            j.put("engine", s.optString("engine", ""));
            j.put("ttsOffline", s.optBoolean("ttsOffline", false));
            j.put("controlError", lastError);
        } catch (Exception ignored) {}
        return j;
    }
}
