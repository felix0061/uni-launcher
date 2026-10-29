package xyz.i4o.uni.launcher.voice;

import org.json.JSONObject;

/** LauncherRuntime 依赖的最小接口：把语音状态并入窗口快照的 voice 块。
 * 服务启动时 attach、停止时 detach；没有服务时快照不含 voice 块。 */
public interface VoiceBridge {
    /** 当前语音状态：{enabled, state, source, listening, ...}，主线程调用。 */
    JSONObject snapshot();
}
