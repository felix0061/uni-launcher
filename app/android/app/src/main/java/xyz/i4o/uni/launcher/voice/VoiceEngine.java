package xyz.i4o.uni.launcher.voice;

import android.content.Context;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import java.util.Locale;

/** 语音引擎抽象：KWS / VAD / ASR / TTS 四段。
 * M1 用 {@link StubVoiceEngine} 跑通全链路；后续用 sherpa-onnx（KWS/VAD/ASR）
 * 与 Edge-TTS（TTS 台湾腔/多音色）替换实现，接口保持不变。 */
public interface VoiceEngine {
    void start();
    void stop();
    /** 唤醒词命中检测（逐帧）。 */
    boolean isWakeWord(short[] pcm, int len);
    /** 唤醒灵敏度 1低/2中/3高；噪音场景（音乐/导航）应调低有效灵敏度。 */
    void setSensitivity(int level);
    /** 单帧是否有语音活动（含噪声门控）。 */
    boolean isSpeech(short[] pcm, int len);
    /** 整段语音转文本，结果异步回调（桩实现直接返回空串）。 */
    void transcribe(short[] pcm, int len, AsrCallback callback);
    /** 文本播报；done 在播放完成后回调（静默失败也回调）。 */
    void speak(String text, Runnable done);
    void cancelSpeak();
    interface AsrCallback { void onResult(String text); }

    /** M1 桩：VAD 用 RMS 能量门控（真实可用的噪声过滤），TTS 走系统 TextToSpeech，
     * KWS/ASR 暂未接入真实模型（KWS 恒 false、ASR 恒空串），由方控按键承担激活。 */
    final class StubVoiceEngine implements VoiceEngine {
        private final Context context;
        private TextToSpeech tts;
        private boolean ttsReady;
        private int speechThreshold = 600; // RMS 阈值，随灵敏度调整

        public StubVoiceEngine(Context context) { this.context = context.getApplicationContext(); }

        @Override public void start() {
            try {
                tts = new TextToSpeech(context, status -> {
                    if (status == TextToSpeech.SUCCESS) {
                        tts.setLanguage(Locale.CHINA);
                        ttsReady = true;
                    }
                });
            } catch (RuntimeException ignored) { tts = null; }
        }

        @Override public void stop() {
            cancelSpeak();
            if (tts != null) { try { tts.shutdown(); } catch (RuntimeException ignored) {} tts = null; }
            ttsReady = false;
        }

        @Override public boolean isWakeWord(short[] pcm, int len) { return false; } // TODO 接 sherpa-onnx KWS「你好 小U」

        @Override public void setSensitivity(int level) {
            // 1 低（不灵敏，阈值高）/ 3 高（灵敏，阈值低）
            speechThreshold = level <= 1 ? 950 : level >= 3 ? 400 : 600;
        }

        @Override public boolean isSpeech(short[] pcm, int len) {
            long sum = 0; int n = Math.min(len, pcm.length);
            for (int i = 0; i < n; i++) { int s = pcm[i]; sum += (long) s * s; }
            return Math.sqrt((double) sum / n) > speechThreshold;
        }

        @Override public void transcribe(short[] pcm, int len, AsrCallback callback) {
            callback.onResult(""); // TODO 接 sherpa-onnx SenseVoice-small
        }

        @Override public void speak(String text, Runnable done) {
            if (!ttsReady || tts == null) { done.run(); return; }
            final String id = "uni-voice-" + System.currentTimeMillis();
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override public void onStart(String utteranceId) {}
                @Override public void onDone(String utteranceId) { done.run(); }
                @Override public void onError(String utteranceId) { done.run(); }
            });
            int result = tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, id);
            if (result != TextToSpeech.SUCCESS) done.run();
        }

        @Override public void cancelSpeak() { if (tts != null) tts.stop(); }
    }
}
