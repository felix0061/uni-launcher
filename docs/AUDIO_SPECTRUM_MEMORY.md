# 真实频谱的内存专项评估

2026-10-27，针对 0.6.13 的频谱实现；生产代码未改动。本次补充测试、数据和说明。

## 结论

频谱有额外内存开销。首次启用会初始化 Visualizer、一个后台线程和绘图资源；只保留 24 个频段数据，不等于总开销只有 24 个数值。

本次 30 次开关/卡片重建、连续 180 秒真实音频采样，没有发现卡片对象/消费者数量累积，或持续采样期间堆内存不断增长的现象。这个结论限于模拟器和已测路径，不能保证实车原生音效链路不存在长期泄漏。

## 测量条件

- Android 9 / API28 x86_64，Flutter profile/AOT。
- 一个固定大小的频谱画布；音频由另一个测试应用用 AudioTrack 连续播放，关闭频谱时音频也保持播放。
- 各检查点先执行 Dart GC，再测应用和 audioserver PSS、Native/Dart 堆、存活对象数、原生消费者数。
- 30 次开关同时更换 Widget key，验证旧卡片实例是否释放。
- 本测试不是完整 release 桌面。以下 PSS 不能与完整桌面、车机地图/播放器同时运行的占用直接比较。

| 检查内容 | 实测结果 |
| --- | --- |
| 冷态关闭频谱，测试音已播放 | 应用 PSS 86.81 MiB |
| 首次启用 5 秒后 | 应用 PSS 91.62 MiB，比冷态多 4.82 MiB |
| 30 次开关/重建后的关闭状态 | 应用 PSS 98.11 MiB；可见 State/Painter 各 1 个，消费者 0 |
| 连续采样 180 秒，6 个检查点 | 应用 PSS 95.58–99.22 MiB；Native Heap PSS 23.63–23.99 MiB |
| 持续采样期间，GC 后 Dart 堆 | 6.769–6.778 MiB |
| 30 次循环后观察采样线程 | 仍为 1 个 |
| 最后关闭频谱 | 原生 running=false、消费者=0、Dart 频段列表清空、数据序号停止 |
| 卸载频谱 Widget 后 GC | State=0、Painter=0、消费者=0；全局单例 Service=1 |

首次检查点的 +4.82 MiB **不是采集器的精确净占用**，包括线程、库、绘图暖机及分配器行为。后续暖机、关闭、卸载控件后，PSS 也没有立即退回冷态：最终关闭为 98.64 MiB，卸载控件后的单个检查点为 103.60 MiB。不能忽略这部分驻留占用，也不能只凭单点 PSS 增加就认定泄漏。

当前实现有意保留一个进程级服务与一个待命线程；它们不会在每次开关时新增。采样器会释放，24 个频段不会存入历史集合。Dart 每帧的新列表会产生分配/GC 开销，但本次 GC 后堆量和存活对象数没有持续累积。原生分配器、动态库和渲染缓存的驻留需要结合更长时间、相同场景的实车记录继续判断。

## 验证范围与下一步

已验证：真实非零 FFT、30 次采集开关和 Widget 替换、180 秒持续采样、关闭后停止输出、Widget 对象回收。未验证：820A 上的准确内存增量、长时间 QQ/网易云/地图并行、车机 DSP/音效实现的原生资源回收、浮窗创建失败等异常路径。

因此可以回答“会增加开销，本次专项测试未发现持续累积的泄漏”；不能回答“频谱只占固定 X MiB”或“已经证明完全没有内存泄漏”。车机应在同一播放器/歌曲/地图/桌面布局下，做开关频谱对照并持续观察 20–30 分钟。

原始证据：`app/verification/audio-spectrum/memory/checkpoints.json`、`summary.json`、各检查点 meminfo 和 `worker-thread-observation.txt`。

```sh
python3 tools/test_audio_spectrum.py --install-fixture
python3 app/tools/flutter_task.py drive \
  --driver=test_driver/audio_spectrum_memory_driver.dart \
  --target=integration_test/audio_spectrum_memory_test.dart --profile -d emulator-5580
```

测试仅允许运行在模拟器；会临时授权录音、启动测试音、在退出时停止测试音。测试音另有 10 分钟自动停止保护。
