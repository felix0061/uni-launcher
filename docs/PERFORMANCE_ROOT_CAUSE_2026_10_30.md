# 领克 05 桌面卡顿排查记录（2026-10-30）

> 后续已连接真车并完成分场景采样，参见 [真车性能实测与优化方案](CAR_PERFORMANCE_FINDINGS_2026_10_30.md)。本文件保留早期静态分析的证据边界；“尚无真车连接”等描述是当时状态，当前结论以新报告为准。

## 结论与适用范围

以用户最后更正为准：**优化模式未开启**。用户反馈涉及桌面翻页、一般操作、嵌入地图拖动三类场景，不能直接当成同一种卡顿。

目前最有证据的排查方向是**桌面帧处理成本与高德渲染、虚拟显示合成共同占用设备资源**。历史车机记录中的 UI、raster 阶段都出现过超过 60Hz 的 16.67ms 预算的情况。但尚不能把当前安装版本的主因锁定为某个函数、光栅缓存不足、阴影、触摸 IPC 或某个 GPU 驱动问题。

本次明确复现了两个优化模式下的代码缺陷，**均不能解释用户当前关闭优化模式时的卡顿**。未修改产品代码，未安装或替换车机应用。本次新增内容仅为诊断探针、记录和采集脚本。

证据边界：

- 分析对象是当前工作区，含已有未提交改动，不等于已经验证用户车机安装包与工作区完全一致。
- 仓库有 2026-10-28 的车机历史数据；不是本次在用户最新配置上的复测。
- 当前 ADB 只连接到 `emulator-5554`。其 ABI 为 x86_64，CPU 为 Intel Xeon；即使 `ro.hardware=qcom`，也不能当作领克真车。
- “嵌入地图缩放”设置、主题、翻页效果、实际应用包哈希尚未从真车读回。

## 1. 已确认的实际链路

### 地图显示

```text
高德 App 的窗口/Surface
  → Android 虚拟显示合成
  → Surface / SurfaceTexture
  → Flutter 外部 Texture
  → 桌面窗口 Surface
  → SurfaceFlinger / 物理屏幕
```

依据：[LiveNavigationHost.java](../app/android/app/src/main/java/xyz/i4o/uni/launcher/platform/LiveNavigationHost.java) `createDisplay()`（约 175 行），以及 [embedded_navigation.dart](../app/lib/widgets/embedded_navigation.dart) `liveMap()`（约 415 行）。这里描述显示合成链路，不代表每个箭头都发生 CPU 内存拷贝。

生产路径使用 `VirtualDisplay + Texture`，并非直接把一个独立原生地图 Surface 交给屏幕显示。这样可以让地图参与 Flutter 卡片裁剪和翻页，但增加了一条合成链路。历史尺寸约为 1229×814；当前实际尺寸依卡片布局和缩放设置而定。

**确认的是架构及其额外工作，尚未测出这条链路在当前车机上占总耗时的比例。** 历史“冻结地图”对翻页的改善很小，也说明不能用这条链路单独解释全部翻页卡顿。

### 地图输入

关闭优化模式时，每个 MOVE 直接走：

```text
Flutter PointerEvent → MethodChannel → Android 主线程
  → 构造 MotionEvent → InputForwarder / Binder → 高德
```

依据：`embedded_navigation.dart:323`、`LiveNavigationHost.java:266`。通道没有主动等待帧末，但上游 Dart、Android 主线程或高德繁忙时仍可能排队。它是地图跟手性需要测量的环节，**不是本次已经证实的主瓶颈**。历史绕过 touch 的对照没有改善翻页，且翻页测试不能替代地图拖动测试。

### 桌面翻页

[page_transition.dart](../app/lib/widgets/page_transition.dart) 保留页面子树，以位置通知驱动变换包装；页面已有 `RepaintBoundary`。地图也有独立边界。不能仅从 `Transform`、`ClipRect` 或地图纹理更新推断“每帧完整重建两页”。

翻页同时显示出入两页，确实扩大合成工作范围；真实的 build、paint、raster、纹理等待和缓存命中情况，需要时间线确认。现有证据不足以声称“两张页面必然撑爆缓存，所以只能整页截图”。

## 2. 历史性能记录说明了什么

来源：[PERFORMANCE_PLAN_0_6_19.md](PERFORMANCE_PLAN_0_6_19.md) 第 15–16 节；原始报告 [after-0618.json](../car-reports/perf/after-0618.json)。

| 历史观察 | 能支持的判断 | 限制 |
| --- | --- | --- |
| 文档记载持续拖动 UI 约 31–46ms、raster 约 24–33ms | 当时各阶段出现明显帧预算不足 | 缺少当前版本同场景的原始时间线；两段不能直接相加换算 FPS |
| 翻页时桌面约 177.8% CPU、高德约 43.2% CPU | 桌面本身有较大工作量，高德也有持续负载 | 4 核合计约 400%，进程 CPU 不能定位具体线程，也不能证明所有核心耗尽 |
| 关阴影、关动态裁剪、绕过 touch 均未明显改善当时翻页 | 没有证据把其中一项当成唯一主因 | 有限次对照，不能说它们毫无成本或对任何场景都无影响 |
| 冻结地图后平均间隔约 52.9→50.8ms | 地图纹理刷新未表现为当时翻页的决定因素 | 不是关闭高德进程/释放虚拟显示，其他资源占用仍可能存在 |
| 旧试验地图缩到 0.75 后 PSS 524→453MB、CPU 44–46%→35% | 降低地图渲染像素数有节省资源的潜力 | 本次 APK/实际场景未做同条件复测；当前缩放算法已不同 |

`after-0618.json` 的版本是 **0.6.18 / versionCode 2031**。报告 interaction 的 p50≈50ms、p90≈117ms、max≈900ms 来自包含滑动和等待的窗口，不能直接当成“纯翻页动画的掉帧分布”。

也没有当前真车的 GC 暂停、内存回收、热降频等证据，不能仅凭“四核、4GB”就诊断为内存不足或设备性能无解。

## 3. 本次确定复现的条件性缺陷

诊断文件：[probe_test.dart](../app/verification/perf-diagnosis/probe_test.dart)，结果：[probe-output.txt](../app/verification/perf-diagnosis/probe-output.txt)。五项诊断均通过；这些断言描述观察到的行为，**不是期望行为的回归验收**。

### 3.1 优化模式开启：地图 MOVE 可能停留在队列中

`embedded_navigation.dart:349` 的 `_queueMove()` 调用 `addPostFrameCallback()`，但没有请求 Dart 帧。空闲桌面收到 MOVE 时，只注册回调不保证执行。外部地图 Texture 更新可以只触发 raster 绘制已有图层，并不保证 Dart 执行 BeginFrame/post-frame。

复现：

```text
优化关闭：发送 DOWN、MOVE、MOVE → 原生立即收到 [0, 2, 2]
优化开启：发送 DOWN、MOVE、MOVE → 原生只有 [0]，且没有请求帧
主动请求一帧之后               → 原生收到 [0, 2]
```

这会导致开启模式后的地图拖动延迟，直到其他刷新或抬手触发发送。**用户当前关闭模式，不走该分支。**

### 3.2 优化模式开启且使用真实模糊：运动冻结会重建地图子树

[glass_surface.dart](../app/lib/widgets/glass_surface.dart) 在运动时于 `BackdropFilter(child)` 与裸 child 间切换，改变子树层级。复现 classic 主题、glass=true，静止→运动→静止后地图 create=3、dispose=2；glass=false 时 create=1、dispose=0。

这不是所有主题通用的问题。`SurfaceStyle.liveBlur` 要求 `glass && !technicalFrame`，blueGlass 主题不走真实模糊；关闭优化模式也不会因运动切换该包装。独立 lift 变换探针保留了地图实例，不能把 lift 本身判为必然重建地图。

## 4. 现有测量中必须纠正的解释

1. **`UNI-MAP amap=` 是消费计数。** 原生 `consumedFrames` 来自 `setOnFrameConsumedListener`，记录纹理被 Flutter 消费，不能当作高德生产帧数。因此“高德 22fps、桌面 12fps，所以丢了一半”需要相同窗口中独立的生产与呈现证据，当前不能成立。
2. **UI 与 raster 有流水线重叠。** `FrameStats` 输出 `total=build+raster`，不能用 `1000/total` 推算稳态 FPS。应分别看各阶段、调度等待与实际 present 时间。`totalSpan > 16.67ms` 也不能替代物理屏幕丢帧统计。
3. **旧脚本混入等待时间。** [car_perf_probe.ps1](../tools/car_perf_probe.ps1) 每次 260ms swipe 后等待 900ms，窗口还含命令往返；静止间隔不是动画长帧。空闲低出帧也不等于卡顿。
4. **旧脚本不验证手势归属。** 固定水平滑动坐标可能落在地图上，被 `EagerGestureRecognizer` 接走；优化模式的 lift 又使用竖向手势。必须确认实际切页，不能只凭 `input swipe` 命令名认定翻页发生。
5. **Android `gfxinfo` 不能代表完整 Flutter 出帧。** 历史报告只记到两个 Android wrapper 帧；应结合 Flutter 时间线、系统调度和 SurfaceFlinger。
6. **缓存溢出、整页重建目前只是猜测。** 当前已有子树隔离，历史文档未附真实 cache miss/逐帧 build 证据。也不能把早期大状态包成本原样套到已做节流、选择性通知的当前代码。

## 5. 最小的真车验证方案

新增 [capture_launcher_jank.py](../tools/capture_launcher_jank.py)：指定 serial；默认拒绝模拟器/x86；记录设备、包版本、显示图层、线程和内存快照；捕获一个 10 秒的手工操作场景及可用的 Android atrace。它不安装 APK、不自动滑动、不改应用配置、不计算混杂的 FPS。设置值由操作者填写，脚本不会伪称已经从应用读回。

在项目根目录执行，例如（把 serial 换成实际车机）：

```powershell
python tools/capture_launcher_jank.py --adb D:\platform-tools\adb.exe --serial 车机地址:5555 --scenario map-pan --seconds 10 --optimize-mode off
```

等 `CAPTURE START` 后，仅持续拖地图；`page-swipe` 场景则从地图外的区域反复切页，确认页面确实变化。其他场景为 `idle`、`tap`、`no-map-page-swipe`、`fullscreen-map-pan`。开始前准备好界面；分别记录主题、缩放、路线/视角和操作方式。脚本不验证具体手势开始时间，分析 trace 时仍须圈定连续操作片段。

当前模拟器没有可用 trace folder，采集器已验证能拒绝错误设备、明确报告跟踪限制并保存诊断元数据，见 [collector-check.json](../app/verification/perf-diagnosis/collector-check.json)。**尚无真车 trace，也尚未验证真车完整采集成功**。不能把工具验证当性能验证。若真车也不开放 atrace，需要使用系统支持的跟踪入口，或另备带 Flutter profiling 的诊断包。

验证顺序：

| 对照 | 固定条件 | 要解决的问题 |
| --- | --- | --- |
| 桌面翻页：地图嵌入开启 vs 真正释放地图虚拟显示 | 同主题、两页内容和手势、同构建模式 | 地图后台/合成负载占多少；仅换到无地图页不保证地图已停 |
| 地图拖动：嵌入 vs 全屏 | 同一 APK、路线/视角、温度、可比渲染像素数 | 地图自身渲染与嵌入链路分别占多少；直接全屏分辨率不同只能作参考 |
| 嵌入地图缩放开 vs 关 | 其他设置相同，记录实际宽高/density | 是否受地图像素量和 GPU/带宽限制；同时检查界面布局和清晰度 |
| 点击反应 | 同一按钮，记录输入→Dart→Android→地图→呈现 | 延迟出在事件排队、应用逻辑，还是最后显示 |

每项至少重复三次，保留原始 trace；先确认 release/profile、包版本及 SHA256 与实际用户版本的关系。通过 UI/raster 事件和 sched 区分计算、被抢占、Binder 等待、GPU/缓冲等待，再决定改哪里。release 中缺少 Dart trace 事件不表示 UI 阶段没有工作。

判定标准：只有某项在固定条件下的对照能稳定消除相应长帧，并且时间线中对应耗时同步下降，才能升级为主要根因。当前不据此承诺某个开关或整页截图能达到 60fps。

## 6. 用户提供的地图包身份

只读取 APK 元数据与资源，未运行、修改或重签该 APK：

| 项目 | 结果 |
| --- | --- |
| 文件 | `F:\Users\Downloads\高德9.5_一指流沙改_共存版_领克车标_去红线_145dpi.apk` |
| SHA256 | `b836fae9caf2404d7902fbad02031010751c6f95beadb76fd1fd6d38538e4b4d` |
| 大小 | 171902408 字节 |
| 包名 | `com.autonavi.amapautp.yh` |
| 版本 | `9.5.0.600013` / `26000092` |
| min/target SDK | 21 / 24 |
| native ABI | arm64-v8a |

资源中的主性能档配置有 fps=50，但不能证明运行时选中了哪个档位或实际输出 50fps；eagleeye fps=2 是鹰眼子模块配置，MultipleScreen 中的 Fps=6 也不能认作主地图帧率。文件名含“145dpi”不等于已经证实运行时密度为 145。历史文档没有记录同一 APK 哈希，不能直接认定过去的高德测试就是此包。
