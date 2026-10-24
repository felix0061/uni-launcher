# 网易云车机版接入

核对版本：`com.netease.cloudmusic.iot` 6.2.81（6002081）。QQ 音乐保持原来的标准 MediaSession 路径。

## 控制

网易云创建 PlaybackState 时只设置状态，没有设置 actions，实际却实现了播放、暂停、前后切歌及 seek 回调。因此不能仅据 actions=0 判定不可控制。

独立的 `NeteaseMediaAdapter` 仅处理这个精确包名。播放/暂停、前后切歌向已选会话发送定向媒体键 DOWN/UP；源码中的接收器消费 UP，存在 500ms 防抖。seek 使用 `TransportControls.seekTo(毫秒)`，播放器内部转换为整秒；按实际时长限制目标。没有全局广播、没有失败重发，也不会控制另一个播放器。发送被接受不等于播放已改变，UI 继续以播放器回调为准。

## 歌词

接收实际存在的三种数据：metadata 的 `android.media.metadata.LYRIC`；`wt_music_lyric` session event 成功状态中的 LRC；`get_lyric_action` event 的三句数组（索引 1 为当前句）。当前句单独显示，不伪造整首歌词或时间轴。切歌、加载、错误时清理旧歌词，并拒绝不匹配的歌曲 ID。

当前安装版本 `assets/ability.json` 没有开启 PlayerConfig.enableLyric，默认关闭。APP 内歌词显示走自己的 UI 链路，对外 MediaSession 上送另有开关。已确认 `show_lyric_action` 只是 UI 指令，不能证明能开启对外上送，桌面不会自动发送它。此版本未上送时明确显示“网易云当前版本未向桌面共享歌词”。未发现可供桌面读取全文的导出 Provider/AIDL；不读取私有缓存、不用网上同名歌曲替代。

## 依据与验证

以上来自现车 APK 的 session 构造、callback、MediaButtonEventReceiver、歌词配置和事件发布代码；嘟嘟的网易云插件使用相同 MediaSession 路径，官方 Launcher3 主要托管媒体中心 Widget。`.inter.apk` 是资源覆盖包，实际接口位于主 APK。原始 APK、字节码与个人媒体日志保存在 Git 忽略的 `car-reports/`。

运行 `python3 android/tools/test-netease-adapter.py` 验证零 actions 按键、seek 单位/边界、QQ 零接触、歌词清理和旧回调隔离。JVM 替身测试不代替实车回调验证；实车结果另见验收记录。
