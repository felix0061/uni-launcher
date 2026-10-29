package xyz.i4o.uni.launcher.voice;

import android.content.Context;
import android.content.SharedPreferences;

/** 语音助手配置：全部落盘到共享的 launcher prefs。
 * 总开关默认关闭，关闭时服务不启动、不录音、零后台开销。 */
public final class VoiceSettings {
    private final SharedPreferences prefs;
    public VoiceSettings(Context context) {
        prefs = context.getSharedPreferences("launcher", Context.MODE_PRIVATE);
    }

    /** 总开关，默认关闭（需求 5）。 */
    public boolean enabled() { return prefs.getBoolean("voiceEnabled", false); }
    public void setEnabled(boolean value) { prefs.edit().putBoolean("voiceEnabled", value).apply(); }

    /** 唤醒词：当前唯一「你好 小U」，模型后续逐个接入（§9.1）。 */
    public String wakeWord() { return prefs.getString("voiceWakeWord", "你好 小U"); }

    /** 音色：Edge-TTS 预置 voiceId，默认小智台湾腔。 */
    public String voiceId() { return prefs.getString("voiceVoiceId", "zh-TW-HsiaoYuNeural"); }
    public void setVoiceId(String value) { prefs.edit().putString("voiceVoiceId", value).apply(); }

    /** 语速 / 音调：Edge-TTS rate/pitch 的百分比偏移（-50..100 / -20..20）。 */
    public int speed() { return prefs.getInt("voiceSpeed", 0); }
    public void setSpeed(int value) { prefs.edit().putInt("voiceSpeed", clamp(value, -50, 100)).apply(); }
    public int pitch() { return prefs.getInt("voicePitch", 0); }
    public void setPitch(int value) { prefs.edit().putInt("voicePitch", clamp(value, -20, 20)).apply(); }

    /** 唤醒灵敏度：1 低 / 2 中 / 3 高；音乐/导航播放时内部再抬高一档（§9.3）。 */
    public int wakeSensitivity() { return prefs.getInt("voiceSensitivity", 2); }
    public void setWakeSensitivity(int value) { prefs.edit().putInt("voiceSensitivity", clamp(value, 1, 3)).apply(); }

    /** TTS 混音：duck（压低音乐/导航，默认）| coexist（允许同播）。 */
    public String ttsMixMode() { return prefs.getString("voiceTtsMixMode", "duck"); }
    public void setTtsMixMode(String value) {
        prefs.edit().putString("voiceTtsMixMode", "coexist".equals(value) ? "coexist" : "duck").apply();
    }

    /** 连续对话：回复结束后保持聆听一段时间，支持多轮（需求追加）。 */
    public boolean continuous() { return prefs.getBoolean("voiceContinuous", true); }
    public void setContinuous(boolean value) { prefs.edit().putBoolean("voiceContinuous", value).apply(); }

    /** 仅本地：不请求云端大模型（车控指令本就只走本地，云端仅闲聊）。 */
    public boolean localOnly() { return prefs.getBoolean("voiceLocalOnly", true); }
    public void setLocalOnly(boolean value) { prefs.edit().putBoolean("voiceLocalOnly", value).apply(); }

    /** 云端对话开关：允许闲聊/问答时联网（车控永不经过云端，§9.5）。 */
    public boolean cloudEnabled() { return prefs.getBoolean("voiceCloudEnabled", false); }
    public void setCloudEnabled(boolean value) { prefs.edit().putBoolean("voiceCloudEnabled", value).apply(); }

    private static int clamp(int value, int min, int max) { return Math.max(min, Math.min(max, value)); }
}
