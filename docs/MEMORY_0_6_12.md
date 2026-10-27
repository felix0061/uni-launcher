# 0.6.12 内存评估与弹窗引擎复用

相关修复随 0.6.13 发布。

2026-10-27，Android 9 / API 28 x86_64 模拟器。本次没有连接车机，不包含高德实景、真实 QQ / 网易云、车辆服务或 820A GPU 的内存。

## 结论

发现全局弹窗反复销毁/创建 FlutterEngine 后，进程原生内存呈累积增长。改为复用唯一的弹窗引擎，关闭 5 秒后移除 FlutterView 窗口、分离渲染表面并通知内存压力；关闭全局底栏/服务时仍销毁全部附属引擎。相同 8 轮测试中，弹窗空闲 PSS 从约 144 MiB 到 150 MiB，没有重现原方案约 151 → 188 MiB 的持续增长。

没有在已测交互中发现 Dart 页面、控制器等对象不断累积的证据。有限时长的模拟器回归不能证明不存在其他泄漏；原生分配器/GPU 资源的保留也不能仅凭 PSS 判定为不可回收泄漏。

## 测量

PSS 为 `adb shell dumpsys meminfo xyz.i4o.uni.launcher` 的 TOTAL，KiB / 1024。Profile 为 AOT 模式。两组控制测试均不调用 VM 分配分析或强制 GC；每轮打开应用、音乐、空调、最近任务四个全局面板，再等待关闭/闲置。

| 检查点 | 原方案：销毁/重建引擎 | 修复：复用引擎 |
| --- | ---: | ---: |
| 启用全局栏，未打开面板 | 131.8 MiB | 133.3 MiB |
| 第一次打开 | 145.3 MiB | 147.0 MiB |
| 2 轮后空闲 | 151.0 MiB | 144.0 MiB |
| 4 轮后空闲 | 166.2 MiB | 144.8 MiB |
| 6 轮后空闲 | 175.0 MiB | 146.7 MiB |
| 8 轮后空闲 | 188.3 MiB | 149.9 MiB |
| 关闭全局栏、后续空闲 | 187.7–194.1 MiB | 141.3–146.5 MiB |

原方案的单桌面 release 冷启动 60 秒观测约 104.7–106.4 MiB，未见持续上升。这与 profile 多引擎压力测试不是同一场景，不应直接当作修复前后对照。

带 VM 分配分析的另一次测试中，45 轮桌面弹窗/设置/换屏后约 152.6 MiB，Dart 页面状态数量没有持续增加。内存上升主要发生在原方案的全局面板引擎反复创建阶段。VM 对共享 isolate group 的 heap usage 不能逐 isolate 相加。

0.6.13 最终 release 包再次安装并冷启动，60 秒空闲 PSS 为 102.4–103.8 MiB，频谱处于未采集状态；记录在 `app/verification/audio-spectrum/release/idle-60s.json`。

## 生命周期约束

- 全局底栏启用、面板打开：主桌面 + 底栏 + 面板，共 3 个引擎。
- 面板关闭 5 秒：面板引擎保留，窗口/渲染表面移除；没有后台绘制，最近任务截图立即清空。
- 再次打开：复用同一个引擎并重新附加窗口。
- 系统发出低内存通知：仍销毁空闲面板引擎，避免为缓存挤占其他应用的内存。
- 关闭全局栏：附属引擎销毁，剩主桌面 1 个引擎。
- 真实音频频谱按可见/播放状态采样，共用一个原生 Visualizer；隐藏、暂停或后台不采样。FFT 不进入通用车辆快照，不驱动整张卡片重建。

## 复现与证据

```sh
UNI_MEMORY_NATIVE_ONLY=1 UNI_MEMORY_OUT=verification/memory-0.6.12/reused-panel \
python3 app/tools/flutter_task.py drive \
  --driver=test_driver/memory_assessment_driver.dart \
  --target=integration_test/memory_assessment_test.dart --profile -d emulator-5580
```

原始检查点和 `dumpsys meminfo` 在 `app/verification/memory-0.6.12/`。`native-only/` 是原实现控制组，`reused-panel/` 是修复后控制组。测试依赖主机端 ADB 授权浮窗，只允许运行于模拟器。

车机下一步：同版本 release、固定地图和音乐源，连续播放 20–30 分钟，循环打开面板并记录 launcher / map / player PSS、系统 available / cached / swap 和 LMKD 事件；比较冷热阶段，才能判断音乐退出是否与系统内存压力有关。
