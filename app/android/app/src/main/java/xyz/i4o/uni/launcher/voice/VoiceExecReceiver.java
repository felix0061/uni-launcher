package xyz.i4o.uni.launcher.voice;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONObject;

import xyz.i4o.uni.launcher.LauncherRuntime;

/** 语音模块的请求入口（只接受同签名应用：manifest 上声明了语音模块的 signature 权限）。
 *
 * 拆包后车辆接口留在桌面，所以「下一首 / 调温度」这类动作由这里落到 LauncherRuntime；
 * 媒体播放状态也在这里回给语音模块，用于唤醒灵敏度联动。 */
public final class VoiceExecReceiver extends BroadcastReceiver {
    private static final String TAG = "UniVoice.Exec";

    @Override public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();
        LauncherRuntime runtime = null;
        try { runtime = LauncherRuntime.get(context); } catch (RuntimeException ignored) {}

        if (VoiceLink.ACTION_EXEC.equals(action)) {
            JSONObject req = new JSONObject();
            try {
                req.put("action", intent.getStringExtra("action"));
                String value = intent.getStringExtra("value");
                if (value != null) req.put("value", value);
                String zone = intent.getStringExtra("zone");
                if (zone != null) req.put("zone", zone);
            } catch (Exception e) {
                setResult("fail");
                return;
            }
            boolean ok = false;
            if (runtime != null) {
                try { ok = runtime.handleVoice(req); } catch (RuntimeException e) { Log.w(TAG, "exec failed: " + e); }
            }
            setResult(ok ? "ok" : "fail");
            return;
        }

        if (VoiceLink.ACTION_MEDIA_QUERY.equals(action)) {
            boolean playing = false;
            if (runtime != null) {
                try { playing = runtime.mediaPlaying(); } catch (RuntimeException ignored) {}
            }
            Bundle b = new Bundle();
            b.putString("playing", playing ? "1" : "0");
            setResultExtras(b);
            return;
        }

        if (VoiceLink.ACTION_STATUS.equals(action)) {
            String what = intent.getStringExtra("what");
            String detail = "";
            if (runtime != null) {
                try { detail = runtime.voiceStatusText(what); } catch (RuntimeException e) { Log.w(TAG, "status failed: " + e); }
            }
            Bundle b = new Bundle();
            b.putString("detail", detail == null ? "" : detail);
            setResultExtras(b);
            return;
        }
        if (VoiceLink.ACTION_STATE.equals(action)) {
            VoiceLink.onState(intent.getStringExtra("state"));
            if (runtime != null) runtime.publish();
        }
    }

    private void setResult(String value) {
        Bundle b = new Bundle();
        b.putString("result", value);
        setResultExtras(b);
    }
}
