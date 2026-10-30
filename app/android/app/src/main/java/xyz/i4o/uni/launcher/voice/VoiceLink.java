package xyz.i4o.uni.launcher.voice;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONObject;

/** 桌面 App 与语音模块之间**唯一**的接线点：开关 + 跳转。
 *
 * 语音已经是独立项目（uni-voice 仓库），媒体、导航、启动应用、车控都在它自己那侧完成，
 * 桌面不再替它执行任何动作，也不再接收它的状态回推。
 *
 *   桌面 → 语音：xyz.i4o.uni.voice.CONTROL {op=enable|disable|status|refresh}
 *   语音 → 桌面：无（有序广播的 setResultExtras 只回一条 enabled）
 */
public final class VoiceLink {
    private static final String TAG = "UniVoice.Link";

    /** 语音 App 顶替了原车小卡的包名（拿 ECARX 语音引擎 + privapp 权限） */
    public static final String VOICE_PACKAGE = "com.ecarx.xiaoka";
    public static final String VOICE_ACTIVITY = "xyz.i4o.uni.voice.VoiceSettingsActivity";
    public static final String ACTION_CONTROL = "xyz.i4o.uni.voice.CONTROL";

    private static final Object LOCK = new Object();
    private static volatile boolean cachedInstalled;
    private static volatile boolean cachedEnabled;
    private static volatile String cachedState = "idle";
    private static volatile String cachedHeard = "";

    /** 语音状态（底栏波形槽位用），由 VoiceStateReceiver 投喂。 */
    static void onState(String state, String heard, boolean enabled) {
        if (state != null && !state.isEmpty()) cachedState = state;
        cachedHeard = heard == null ? "" : heard;
        cachedEnabled = enabled;
        cachedInstalled = true;
    }

    private VoiceLink() {}

    public static boolean installed(Context context) {
        try {
            context.getPackageManager().getPackageInfo(VOICE_PACKAGE, 0);
            cachedInstalled = true;
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            cachedInstalled = false;
            return false;
        }
    }

    /** 有序广播问一次「现在开着没有」，结果进缓存，界面下次读 snapshot 就更新。 */
    public static void refresh(Context context) {
        sendControl(context, "status", null);
    }

    public static void setEnabled(Context context, boolean enabled, Runnable done) {
        sendControl(context, enabled ? "enable" : "disable", done);
    }

    private static void sendControl(Context context, String op, Runnable done) {
        try {
            Intent i = new Intent(ACTION_CONTROL)
                    .setPackage(VOICE_PACKAGE)
                    .putExtra("op", op);
            context.sendOrderedBroadcast(i, null, new android.content.BroadcastReceiver() {
                @Override public void onReceive(Context c, Intent intent) {
                    Bundle b = getResultExtras(false);
                    if (b != null) {
                        cachedInstalled = true;
                        cachedEnabled = b.getBoolean("enabled", cachedEnabled);
                        String err = b.getString("error", "");
                        if (err != null && !err.isEmpty()) Log.w(TAG, "语音模块回报：" + err);
                    }
                    if (done != null) done.run();
                }
            }, null, 0, null, null);
        } catch (RuntimeException e) {
            Log.w(TAG, "发送控制指令失败: " + e);
            if (done != null) done.run();
        }
    }

    /** 打开语音 App 的设置界面。 */
    public static void openSettings(Context context) {
        try {
            Intent i = new Intent();
            i.setComponent(new ComponentName(VOICE_PACKAGE, VOICE_ACTIVITY));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(i);
        } catch (RuntimeException e) {
            Log.w(TAG, "打不开语音设置: " + e);
        }
    }

    /** 桌面设置面板只需要两个字段：装没装、开没开。 */
    public static JSONObject snapshot(Context context) {
        JSONObject j = new JSONObject();
        try {
            j.put("installed", installed(context))
             .put("enabled", cachedEnabled)
             .put("state", cachedState)
             .put("heard", cachedHeard);
        } catch (Exception ignored) {}
        return j;
    }
}
