package xyz.i4o.uni.launcher.voice;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** 只接收语音模块的**状态**（供底栏波形槽位显示），不执行任何指令。
 *
 * 语音是独立项目，控制边界在它那边；桌面这里只订阅「现在在干嘛、听到了什么」。
 */
public final class VoiceStateReceiver extends BroadcastReceiver {
    static final String ACTION = "xyz.i4o.uni.launcher.VOICE_STATE";

    @Override public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        VoiceLink.onState(
                intent.getStringExtra("state"),
                intent.getStringExtra("heard"),
                intent.getBooleanExtra("enabled", false));
    }
}
