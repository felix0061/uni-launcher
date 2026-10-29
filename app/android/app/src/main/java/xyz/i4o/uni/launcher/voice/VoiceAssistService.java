package xyz.i4o.uni.launcher.voice;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import xyz.i4o.uni.launcher.LauncherRuntime;

/** 语音助手前台服务：全局存在、默认不启动（voiceEnabled=false）。
 * 状态机：IDLE → LISTENING → THINKING → SPEAKING →（连续对话）→ LISTENING → IDLE。
 * M1 激活源为方控语音键；唤醒词待 sherpa-onnx KWS 接入后作为第二种激活源。 */
public final class VoiceAssistService extends Service implements VoiceBridge {
    private static volatile VoiceAssistService active;
    private static final int SAMPLE_RATE = 16000;
    private static final int FRAME_SAMPLES = 320;      // 20ms 一帧
    private static final int SILENCE_END_FRAMES = 25;  // 500ms 静音断句
    private static final int MIN_SPEECH_FRAMES = 8;    // 160ms，过滤瞬时噪声（咳嗽/关门）
    private static final int MAX_SPEECH_FRAMES = 500;  // 10s 上限
    private static final int LISTEN_TIMEOUT_MS = 8000; // 连续对话聆听超时

    private final Handler main = new Handler(Looper.getMainLooper());
    private VoiceSettings settings;
    private VoiceEngine engine;
    private LauncherRuntime runtime;
    private AudioRecord recorder;
    private volatile boolean capturing;
    private State state = State.IDLE;
    private String source = "steering";

    enum State { IDLE, LISTENING, THINKING, SPEAKING, UNAVAILABLE }

    private final Runnable listenTimeout = () -> { if (state == State.LISTENING) enterIdle(); };

    /** 方控语音键激活入口（也可作为未来唤醒词的统一入口）。 */
    public static void activate(Context context, String source) {
        if (!new VoiceSettings(context).enabled()) return;
        Intent intent = new Intent(context, VoiceAssistService.class).putExtra("activate", source == null ? "steering" : source);
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent);
        else context.startService(intent);
    }

    public static void ensureStarted(Context context) {
        if (!new VoiceSettings(context).enabled()) return;
        Intent intent = new Intent(context, VoiceAssistService.class);
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent);
        else context.startService(intent);
    }

    public static void stop(Context context) { context.stopService(new Intent(context, VoiceAssistService.class)); }

    /** 方控语音键：标准 VOICE_ASSIST/ASSIST(219) + SEARCH(84) 作为兜底。 */
    public static boolean isVoiceKey(int keyCode) {
        return keyCode == android.view.KeyEvent.KEYCODE_VOICE_ASSIST
            || keyCode == android.view.KeyEvent.KEYCODE_ASSIST
            || keyCode == android.view.KeyEvent.KEYCODE_SEARCH;
    }

    @Override public void onCreate() {
        super.onCreate();
        active = this;
        settings = new VoiceSettings(this);
        if (!settings.enabled()) { stopSelf(); return; }
        runtime = LauncherRuntime.get(this);
        engine = new VoiceEngine.StubVoiceEngine(this);
        engine.start();
        runtime.attachVoice(this);
        startForeground(754, notification());
        publish();
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.hasExtra("activate")) {
            beginListening(intent.getStringExtra("activate"));
        }
        return START_STICKY;
    }

    @Override public void onDestroy() {
        active = null;
        stopListening();
        if (engine != null) { engine.stop(); engine = null; }
        if (runtime != null) { runtime.attachVoice(null); runtime = null; }
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }

    // ---- 状态机（主线程） ----

    private void beginListening(String src) {
        if (engine == null) return;
        source = src == null ? "steering" : src;
        applySensitivity();
        if (!openRecorder()) {
            setState(State.UNAVAILABLE);
            speak("麦克风暂不可用，请检查录音权限");
            return;
        }
        setState(State.LISTENING);
        startCaptureLoop();
        scheduleListenTimeout();
    }

    /** A3：音乐/导航播放时把有效灵敏度降一档，减少把音乐当语音的误判。 */
    private void applySensitivity() {
        int base = settings.wakeSensitivity();
        boolean noisy = runtime != null && runtime.mediaPlaying();
        engine.setSensitivity(noisy ? Math.max(1, base - 1) : base);
    }

    private void startCaptureLoop() {
        capturing = true;
        new Thread(() -> {
            ByteArrayOutputStream speech = new ByteArrayOutputStream();
            short[] frame = new short[FRAME_SAMPLES];
            int speechFrames = 0, silenceFrames = 0;
            boolean started = false;
            byte[] result = null;
            try {
                while (capturing) {
                    int read;
                    try { read = recorder.read(frame, 0, FRAME_SAMPLES); }
                    catch (RuntimeException e) { read = -1; }
                    if (read <= 0) { main.post(() -> setState(State.UNAVAILABLE)); break; }
                    if (engine.isSpeech(frame, read)) {
                        started = true; silenceFrames = 0; speechFrames++;
                        append(speech, frame, read);
                    } else if (started) {
                        silenceFrames++;
                        append(speech, frame, read); // 保留句尾静音
                        if (silenceFrames >= SILENCE_END_FRAMES) break;
                    }
                    if (speechFrames >= MAX_SPEECH_FRAMES) break;
                }
                if (started && speechFrames >= MIN_SPEECH_FRAMES) result = speech.toByteArray();
            } finally {
                capturing = false;
            }
            final byte[] pcm = result;
            main.post(() -> onSpeechCaptured(pcm));
        }, "uni-voice-capture").start();
    }

    private void onSpeechCaptured(byte[] pcm) {
        main.removeCallbacks(listenTimeout);
        if (state != State.LISTENING) return;
        if (pcm == null) { // 只有瞬时噪声：当作没说话，继续听
            if (state == State.LISTENING) { startCaptureLoop(); scheduleListenTimeout(); }
            return;
        }
        setState(State.THINKING);
        short[] samples = toShorts(pcm);
        engine.transcribe(samples, samples.length, text -> main.post(() -> onAsr(text)));
    }

    private void onAsr(String text) {
        if (text == null || text.isEmpty()) { speakAndMaybeContinue("没听清，请再说一次"); return; }
        VoiceCommand.Result r = VoiceCommand.parse(text);
        if (!r.recognized) { speakAndMaybeContinue("没听清，请再说一次"); return; }
        boolean executed = execute(r);
        speakAndMaybeContinue(executed ? r.reply : "这个功能还在适配中");
    }

    /** 命令统一走 LauncherRuntime（A2：执行瞬间保障车辆/媒体源就绪）。 */
    private boolean execute(VoiceCommand.Result r) {
        if (runtime == null) return false;
        try {
            JSONObject req = new JSONObject().put("action", r.action);
            if (r.value != null) req.put("value", r.value);
            if (r.zone != null) req.put("zone", r.zone);
            return runtime.handleVoice(req);
        } catch (Exception e) { return false; }
    }

    private void speakAndMaybeContinue(String reply) {
        setState(State.SPEAKING);
        engine.speak(reply, () -> main.post(() -> {
            if (state != State.SPEAKING) return;
            if (settings.continuous()) beginListening(source); // 多轮连续对话
            else enterIdle();
        }));
    }

    private void speak(String reply) {
        setState(State.SPEAKING);
        engine.speak(reply, () -> main.post(() -> { if (state == State.SPEAKING) enterIdle(); }));
    }

    private void enterIdle() {
        stopListening();
        setState(State.IDLE);
    }

    private void scheduleListenTimeout() {
        main.removeCallbacks(listenTimeout);
        main.postDelayed(listenTimeout, LISTEN_TIMEOUT_MS);
    }

    private void stopListening() {
        capturing = false;
        main.removeCallbacks(listenTimeout);
        if (recorder != null) {
            try { recorder.stop(); } catch (RuntimeException ignored) {}
            try { recorder.release(); } catch (RuntimeException ignored) {}
            recorder = null;
        }
    }

    private boolean openRecorder() {
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false;
        try {
            int min = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            recorder = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, Math.max(min * 2, SAMPLE_RATE));
            if (recorder.getState() != AudioRecord.STATE_INITIALIZED) { recorder.release(); recorder = null; return false; }
            recorder.startRecording();
            return true;
        } catch (RuntimeException e) { recorder = null; return false; }
    }

    private void setState(State next) { state = next; publish(); }

    private void publish() { if (runtime != null) runtime.publish(); }

    @Override public JSONObject snapshot() {
        JSONObject j = new JSONObject();
        try {
            j.put("enabled", settings.enabled())
             .put("available", engine != null && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)
             .put("state", state.name().toLowerCase())
             .put("source", source)
             .put("wakeWord", settings.wakeWord())
             .put("voiceId", settings.voiceId())
             .put("speed", settings.speed())
             .put("pitch", settings.pitch())
             .put("wakeSensitivity", settings.wakeSensitivity())
             .put("ttsMixMode", settings.ttsMixMode())
             .put("continuous", settings.continuous())
             .put("localOnly", settings.localOnly())
             .put("cloudEnabled", settings.cloudEnabled());
        } catch (Exception ignored) {}
        return j;
    }

    private Notification notification() {
        String channelId = "uni-voice";
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (nm != null) nm.createNotificationChannel(new NotificationChannel(channelId, "语音助手", NotificationManager.IMPORTANCE_LOW));
            return new Notification.Builder(this, channelId).setContentTitle("UNI 语音助手").setContentText("正在监听").setSmallIcon(android.R.drawable.ic_btn_speak_now).build();
        }
        return new Notification.Builder(this).setContentTitle("UNI 语音助手").setContentText("正在监听").setSmallIcon(android.R.drawable.ic_btn_speak_now).build();
    }

    private static void append(ByteArrayOutputStream out, short[] frame, int len) {
        byte[] b = new byte[len * 2];
        for (int i = 0; i < len; i++) { int s = frame[i]; b[i * 2] = (byte) (s & 0xff); b[i * 2 + 1] = (byte) ((s >> 8) & 0xff); }
        out.write(b, 0, b.length);
    }

    private static short[] toShorts(byte[] pcm) {
        short[] s = new short[pcm.length / 2];
        for (int i = 0; i < s.length; i++) s[i] = (short) ((pcm[i * 2] & 0xff) | (pcm[i * 2 + 1] << 8));
        return s;
    }
}
