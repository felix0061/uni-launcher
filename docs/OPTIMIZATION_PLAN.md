# UNI桌面优化方案 v1

> 基线：`0.6.18+31`（IP753 实车数据见 `PERFORMANCE_PLAN_0_6_19.md`）
> 归因依据：[WHY_JJ_SMOOTHER.md](WHY_JJ_SMOOTHER.md)
> 本文只写**能落地、能验收、能回滚**的项，每一项都标了改哪个文件、预期多少 ms、风险、回滚方式。已经被 A/B 证伪的方案统一放在 §6「不要做」。

---

## 0. 目标与验收口径

### 0.1 当前基线（同一台车实测）

| 指标 | 值 | 来源 |
|---|---|---|
| 翻页帧间隔 | p50 33.3 ms / p90 66.6 ms / 平均 52.9 ms，44% 帧 ≤20 ms | 实车 |
| 持续拖动 | 12–15 fps（UI 31–46 ms + raster 24–33 ms） | 实车 |
| 静止出帧 | 无地图页 1.0–1.4 fps；含地图页 11.4–11.9 fps | 实车 |
| 空闲 CPU | 无地图页 13.9%；含地图页 34.8% | 实车 |
| 冷启动中位 | 2521 ms（应用侧 870 ms，其余是引擎+首帧） | 实车 |
| PSS | 地图挂载 198–235 MB（Graphics 127–147 MB）；未挂载 112 MB | 实车 |
| 高德呈现 | 生产 22.1 fps / 窗口 11.8–13.3 fps（丢一半帧） | 实车 |

### 0.2 目标（v1 验收）

| 指标 | 目标 | 判定方式 |
|---|---|---|
| 翻页 | p50 ≤ 16.7 ms，≥80% 帧 ≤20 ms | `SurfaceFlinger --latency`，4 轮滑动 |
| 持续拖动 | ≥30 fps | 同上，2.5 s 不松手 |
| 地图呈现 | ≥ 生产端 80%（即 ≥16 fps） | 对比 `mapViews.consumedFrames` 与高德自身帧数 |
| 空闲 CPU（无地图页） | ≤10% | `top -H` 10 s 中位 |
| 冷启动 | ≤2200 ms | `am start -W` 6 轮中位 |
| PSS（地图挂载） | ≤190 MB | `meminfo` |

---

## 1. 优先级总表

| # | 项 | 层 | 工作量 | 预期收益 | 风险 |
|---|---|---|---|---|---|
| A1 | 修「内嵌地图被高德抢回前台」 | 原生 | 0.5–1 天 | 消除"导航卡有时候不动"，地图呈现从 11.8 → ~22 fps | 低 |
| A2 | 翻页形态改「淡入 + 60dp 上浮 + 0.98→1.0」 | Flutter | 1 天 | 需重录面积与时长同时下降；p50 33.3 → 16.7（估） | 低（视觉口径要确认） |
| A3 | 动画/交互期冻结重活（毛玻璃、能量流、频谱、歌词 tick） | Flutter | 1 天 | 翻页期整帧 −10 ms 以上（glass 模式） | 低 |
| A4 | 拖动手势里地图 touch 转发节流（每帧最多 1 次） | Flutter+原生 | 0.5 天 | 消掉 2.5 s 内约 150 次 IPC 的排队 | 低 |
| B1 | 页级纹理翻页（出场页快照 → `ui.Image`，动画期只位移） | Flutter | 3 天 | UI 33–39 → ~5 ms，raster 24–37 → 2–4 ms（估） | 中（地图 Texture 无法快照，要分层处理） |
| B2 | 卡片背景预烘焙（阴影+填充+边框 → `ui.Image`） | Flutter | 2 天 | 单卡重绘 8–15 ms → <1 ms（估） | 中（视觉需截图对照） |
| B3 | 去掉只为阴影服务的外层 `ClipRRect` + 减少包装层 | Flutter | 0.5 天 | 每卡每帧省一次 clip，避免打断批处理 | 低 |
| C1 | Impeller 四组 A/B（`vulkan`/`opengles`/lazy-shader/antialias-off） | 配置 | 0.5 天 | 未知，可能整体 ±20% | 低（一行 meta-data） |
| C2 | 面板复用底栏引擎（少一个引擎 + raster 线程） | 原生 | 1–2 天 | −10~20 MB，少一套线程 | 中（isolate 状态隔离） |
| C3 | 去全屏 `FittedBox` 1.2×（设计画布按真实宽度定标） | Flutter | 2 天 | 文本/图标不再重采样 | 高（要改 `design_contract_test` 锚点） |
| C4 | 相邻页空闲预光栅 | Flutter | 2 天 | 消掉入场页首帧 100–166 ms 长帧 | 中 |
| C5 | 引擎常驻 / HOME 不重建 | 原生 | 1 天 | 回桌面不再走完整引擎启动（−1~2 s，估） | 中（常驻内存 +50 MB） |

**实施顺序**：A 组一次打包出（3–4 天），量完再决定 B 组；C1 可以和 A 组同包（配置开关）；C2–C5 放后续版本。

---

## 2. A 组：先拿体感（1 个迭代）

### A1. 修「内嵌地图被高德抢回前台」

**现象**（实车已记录）：`mCurrentFocus` 从 `xyz.i4o.uni.launcher/.MainActivity` 跳到 `com.autonavi.amapautp.yh/com.autonavi.amapauto.MainMapActivity`，同时 `taskMoves` 增加、`consumedFrames` 停止增长 → 导航卡变成 0 fps 死图，直到再次进桌面。

**原因**：`LiveNavigationHost.activate()`（`platform/LiveNavigationHost.java:188`）只在进入/切页时把任务搬进虚拟屏；高德自己（车机版有自启动/自恢复逻辑）把任务搬回 display 0 后，没人再搬回来。

**改法**：加一个「归属看护」，只在地图卡可见时跑。

```java
// LiveNavigationHost.LiveMap 内
private final Runnable ownershipWatch = new Runnable() {
    @Override public void run() {
        if (disposed || !hostVisible || !requestedVisible) { main.removeCallbacks(this); return; }
        try {
            ComponentName owner = placeExistingTask();      // 已有：getAllStackInfos + moveStackToDisplay
            if (owner == null) {                            // 任务不在了 → 重新启动一次
                if (launchCount < 3) activate();
            } else if (!ready) {
                awaitingFrame.set(true); phase = "loading"; publish();
            }
        } catch (Exception | LinkageError e) {
            Log.w("UniMap", "ownership watch", e);
        }
        main.postDelayed(this, ready ? 1500 : 500);
    }
};
```

启动/恢复时机：`activate()` 成功后 `main.postDelayed(ownershipWatch, 800)`；`setVisible(true)` 时也要重新 arm 一次；`setVisible(false)` 立刻 `removeCallbacks`。

**注意**：
- 不要用无限轮询——`ready == true` 时降到 1.5 s，且只在 `hostVisible && requestedVisible` 时跑。
- 与 `verifyPlacement()`（`:222`，20 次×250 ms）合并，避免两套重试打架：把 `verifyPlacement` 改成调用同一个 `ownershipWatch`。
- 若高德是被用户主动切到前台（用户点了"全屏打开"），要能识别：检查 `mCurrentFocus` 的包名是否为导航包且 **task id 等于我们记的 `embeddedTaskId`**，只有同一个任务被搬走才抢回来。

**验收**：进桌面 → 打开高德 → 返回桌面 → 连续 3 分钟不碰，`dumpsys window | grep mCurrentFocus` 一直是 launcher；`mapViews.consumedFrames` 持续增长。

---

### A2. 翻页形态：淡入 + 60dp 上浮 + 0.98→1.0

**为什么**：横向整页平移要两页各 1920 宽同时可见、逐帧重录（实测 UI 33–39 ms）。君君桌面用 `alpha/translationY/scale` 三个 RenderNode 属性 + 入场页置顶，位移只有 60dp，抖动藏在 600 ms 淡入里。

**改法**：在 `widgets/page_transition.dart` 新增 effect `lift`（并设为默认，保留 `slide/fade/depth/zoom/none`）：

```dart
// _PageTransform.build，effect 分支里加
final lift = switch (effect) {
  'lift' when entering => (1.0 - amount) * 60.0,      // 入场页从 +60dp 升到 0
  'lift' => -(1.0 - amount) * 24.0,                    // 出场页轻退
  _ => 0.0,
};
final sign = entering ? 1.0 : -1.0;
...
return ClipRect(
  clipper: /* lift 不需要 _UncoveredPageClipper，整页可见 */
      effect == 'lift' ? null : (……原逻辑……),
  child: Transform.translate(
    offset: Offset(offset * Design.px(24), Design.px(lift)),
    child: FractionalTranslation(translation: Offset(offset, 0), ...)));
```

并且在 `build()` 的 `order` 计算里对 `lift` 也做「入场页置顶」（现在只有 `depth` 做）：

```dart
if (widget.effect == 'depth' || widget.effect == 'lift') {
  order.remove(_toPage);
  order.add(_toPage);
}
```

时长：`_settle()`（`:143-148`）现在是 `140 + distance*120` ms，`lift` 建议 **220–300 ms**（淡入太短会闪，太长会显得慢）。

**为什么能省**：
- 位移量从整页宽（1920px）降到 60dp，出页不再需要 `_UncoveredPageClipper` 逐帧重算裁剪；
- 入场页置顶 + 出场页 alpha 递减，两页的重叠面积与混合成本下降；
- 竖直位移不改变水平可见区，`ClipRect` 可以在动画期间保持不变（不再每帧换 clipper）。

**风险**：视觉变化需要产品/你自己确认（`MEDIA_LYRICS_AND_MOTION.md` 里有动效口径）。保留 `slide` 作为可选项即可回滚。

---

### A3. 动画期冻结重活

`DesktopMotionScope` 已经存在（`page_transition.dart:9-21`）但**目前没有任何消费者**（grep `DesktopMotionScope.movingOf` 为空）——正好用来做"运动期降载"。

三处接入：

1. **卡片毛玻璃**（`widgets/glass_surface.dart:89-93`）
```dart
final moving = DesktopMotionScope.movingOf(context);
... s.liveBlur && !moving ? BackdropFilter.grouped(...) : framed
```
运动期退化成半透明纯色（视觉上几乎无差，因为整页在动），静止后恢复模糊。

2. **能量流动画**（`widgets/vehicle_cards.dart:139-175`）
```dart
// build 里
final moving = DesktopMotionScope.movingOf(context);
if (moving != _lastMoving) { _lastMoving = moving; tickerEnabled = !moving; }
// 并在 moving 时 controller.stop()、结束 controller.forward(from: 0)
```

3. **歌词/进度 tick**：`MusicManager` 侧的 250 ms / 1 s Timer 已有 TickerMode 暂停逻辑（0.6.11 记录），把 `TickerMode` 的 `enabled` 与 `!_moving` 对齐即可（`page_transition.dart:226-227` 现在就写了 `enabled: !_moving && i == page`，确认 `DesktopMotionScope` 与 `TickerMode` 不冲突）。

**预期**：glass 外观下翻页整帧 −10 ms 以上；能量流常亮时桌面从"永久 60fps 出帧"变成"只有可见页出帧"。

---

### A4. 拖动时地图 touch 转发节流

**现状**：每个 `PointerMove` 一次 MethodChannel + 一次 `MotionEvent` 注入（2.5 s 约 150 次）。

**改法（Flutter 侧）**：在 `map` 卡的手势回调里把 move 事件合并到帧末发一次：

```dart
Offset? _pendingPointers; int? _pendingAction;
void _onTouch(Map<String, dynamic> event) {
  final action = event['action'] as int;
  if (action == 2) { _pending = event; scheduleSend(); return; }  // MOVE 只留最新
  flush(); send(event);
}
void scheduleSend() {
  if (_flushScheduled) return;
  _flushScheduled = true;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    _flushScheduled = false;
    if (_pending != null) { send(_pending!); _pending = null; }
  });
}
```

**注意**：这不是"关掉 touch 转发"（实测关掉 fps 反而降），而是**去重**——指针只保留最后一帧位置，语义不变。

---

## 3. B 组：结构性改造（第二个迭代）

### B1. 页级纹理翻页

**目标**：把「每帧重录两页」变成「每帧画两张位图」。

**分两版，先做低风险版**：

**v1（只快照出场页，1–1.5 天）**
- 出场页在动画期间内容不变，所以可以在 `dragStart()` / `_settle()` 开始时把它光栅成一张 `ui.Image`；
- 实现：给每页套 `RepaintBoundary(key: _pageKey[i])`（已有 `RepaintBoundary`，加 GlobalKey），`RenderRepaintBoundary.toImage(pixelRatio: devicePixelRatio)`；
- 动画期把出场页替换成 `RawImage(image: snapshot, fit: BoxFit.fill)`，动画结束 `snapshot.dispose()`；
- **地图卡例外**：`Texture` 走 GPU 合成，`toImage` 拿不到它 → 出场页里地图区域会是空白。v1 处理：出场页保持实时渲染，只快照**非地图卡**区域的做法不可行（会重叠），所以 v1 只在「出场页不含地图卡」时启用（第 2、3 页大部分情况成立），含地图卡则退回 A2 的轻量形态。

**v2（两页都快照，2 天）**
- 入场页也要快照：在**上一个静止期**就预热（`scheduleIdleTask`，页面隐藏时也可预热），缓存 `ui.Image` 并记录 `revision`；
- 地图卡用「快照 + 实时 Texture 叠层」：快照时该位置留黑/留底图，动画期间在该矩形位置叠一个 `Texture` widget（它本来就是 GPU 层，不参与光栅），
- 页面内容变更（数据刷新/编辑）时 `revision++` 使快照失效。

**风险与对策**：

| 风险 | 对策 |
|---|---|
| 快照与实时的像素差（字形 hinting、抗锯齿） | 动画期间几乎不可辨；静止立刻切回实时 |
| 快照那次 `toImage` 本身要一帧时间 | 放在 `dragStart` 前（首次进入页面后的空闲期就做），拖动开始时不付这个成本 |
| 地图区域空白 | v1 按"含地图卡则不用快照"退化；v2 用 Texture 叠层 |
| 显存 | 每页 1920×1080×4 ≈ 8.3 MB，仅保留"当前+相邻"最多 3 张 ≈ 25 MB，进入后台/内存压力时 `dispose` |
| 现有契约 | `layout_test.dart` 有"native map must be hidden before Flutter paints another page"，快照层要遵守同样的隐藏顺序 |

**预期**：按 `PERFORMANCE_PLAN_0_6_19.md` §16.4 的估算，UI 33–39 ms → 数 ms，raster 24–37 ms → 2–4 ms。

---

### B2. 卡片背景预烘焙

**目标**：把每卡「一次高斯 + 两次 clip + 一次 border」变成「一次 blit」。

```dart
// 新增 widgets/baked_surface.dart
final _cache = <int, ui.Image>{};           // key = 尺寸+样式+圆角+阴影

Future<ui.Image> _bake(double w, double h, SurfaceStyle s, bool shadow) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), s.radius);
  if (shadow) {
    canvas.drawRRect(rrect.shift(Offset(0, Design.px(10))),
        Paint()..color = s.shadow..maskFilter = MaskFilter.blur(BlurStyle.normal, Design.px(20)));
  }
  canvas.drawRRect(rrect, Paint()..shader = /* 填充/渐变 */);
  canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = s.edge);
  return rec.endRecording().toImage(w.ceil(), h.ceil());
}
```

使用处（`glass_surface.dart:73-94`）：外层换成 `CustomPaint(painter: _BakedPainter(image), child: ClipRRect(...内容...))`。

- 缓存键必须包含：宽度、高度、圆角、阴影颜色/模糊/偏移、填充色/渐变、边框色；
- LRU 限 20 张（1920×1080 单卡 ~1 MB，实际卡片更小）；
- 尺寸变化（旋转/布局切换）时重建，旧图 `dispose()`；
- 视觉对照：截图逐像素比对（阴影边缘可能有 1px 抗锯齿差异，可接受）。

**预期**：单卡重绘 8–15 ms → <1 ms【估】；页面级 −5~7 ms（已有实测支撑：阴影关掉是 −5~7 ms，预烘焙后保留视觉但成本接近关掉）。

---

### B3. 去掉只为阴影服务的外层 `ClipRRect` + 减少包装层

现状（`glass_surface.dart:73-94`）：

```
DecoratedBox(圆角 + BoxShadow)      ← 外层，没有 clip
└── ClipRRect                        ← 只为把阴影裁进圆角（其实阴影本身已是圆角矩形）
    └── [BackdropFilter] → DecoratedBox(填充+边框) → Material → Padding → child
```

改法：阴影放外层 `DecoratedBox`（已经这样了），**内层 `ClipRRect` 只保留一次**，删掉重复裁剪；`BackdropFilter` 与 `ClipRRect` 的嵌套顺序调整为「先 clip 再 blur」以避免整卡离屏。

配合 A3 已经能把 glass 在运动期关掉，这条在静止期省一次 clip。

---

## 4. C 组：按 A/B 结果决定

### C1. Impeller 四组 A/B（一行配置，先做）

`AndroidManifest.xml` 的 `<application>` 下加：

```xml
<meta-data android:name="ImpellerBackend" android:value="opengles"/>
<!-- 可选叠加 -->
<meta-data android:name="ImpellerLazyShaderInitialization" android:value="true"/>
<meta-data android:name="ImpellerAntialiasLines" android:value="false"/>
```

四组：默认（Vulkan/GLES 由引擎决定）／`opengles`／`opengles`+lazy ／`opengles`+lazy+antialias-off。
每组用 `tools/car_perf_probe.ps1 -Label impeller-<n>` 采一轮，比 `interaction` 的 p50/p90 与 `coldStart`。

**先看日志确认车机用的是哪个后端**：`adb logcat -d | grep -i "Impeller rendering backend"`。

### C2. 面板复用底栏引擎
`GlobalDockService` 现在给 `globalDockMain` / `globalPanelMain` 各建一个引擎。改成同一引擎切 root widget，省一套 Dart 堆 + raster 线程（−10~20 MB）。风险在 isolate 状态隔离，需要检查两个 entrypoint 的耦合。

### C3. 去全屏 `FittedBox` 1.2×
`screens/launcher_shell.dart:93-97`。风险：`design_contract_test.dart` 锚定的是缩放后的成品几何（`closeTo(14.9333)`、`933.333`、`left 62`/`width 96`），要同步改验收口径。收益是文本/图标不再重采样，属于"能省一点但要动验收"的项，放最后。

### C4. 相邻页空闲预光栅
和 B1 的 v2 共用同一套快照机制，做完 B1 基本免费。

### C5. 引擎常驻 / HOME 不重建
`MainActivity.java:54` `shouldDestroyEngineWithHost(){return true;}` → 回桌面时引擎销毁，下次重建。改成 `false` + 引擎单例（`provideFlutterEngine` 返回缓存实例），可省掉回桌面的引擎启动；代价是常驻内存 +50 MB 左右，2 GB 内存的老车机要评估（可用 `onTrimMemory(TRIM_MEMORY_UI_HIDDEN)` 时主动释放纹理缓存）。

---

## 5. 验收流程（每一项都要走）

```bash
# 0) 记录包身份，确保 A/B 同证书
adb shell pm path xyz.i4o.uni.launcher
pwsh tools/car_perf_probe.ps1 -Label <基线/改动名>

# 1) 翻页（4 轮，取中位）
pwsh tools/car_perf_probe.ps1 -Label A2-lift-r1
pwsh tools/car_perf_probe.ps1 -Label A2-lift-r2

# 2) 拖动 + 地图帧
adb shell dumpsys SurfaceFlinger --latency "$(adb shell dumpsys SurfaceFlinger --list | grep -i 'uni' | head -1)"
adb logcat -s UniMap   # consumedFrames / taskMoves / launchCount

# 3) 空闲
adb shell dumpsys gfxinfo xyz.i4o.uni.launcher reset; sleep 10
adb shell dumpsys gfxinfo xyz.i4o.uni.launcher | grep -E 'Total frames|Janky'
adb shell top -H -p $(adb shell pidof xyz.i4o.uni.launcher) | head -12

# 4) 内存
adb shell dumpsys meminfo xyz.i4o.uni.launcher | grep -E 'TOTAL|Native Heap|Graphics'

# 5) 冷启动（6 轮取中位）
for i in 1 2 3 4 5 6; do adb shell am force-stop xyz.i4o.uni.launcher; adb shell am start -W -n xyz.i4o.uni.launcher/.MainActivity | grep TotalTime; done
```

**判读规则**：
- `UniPerf` 有告警 → 还有负载漏进增量包（先修数据链路）
- `Total frames rendered` 静止 10 s 接近 600 → 能量流/频谱在常亮（A3 没生效）
- 翻页 p50 仍在 33.3 → B1 没生效，或快照被立即失效（检查 `revision`）
- 地图 `consumedFrames` 不涨而 `taskMoves` 涨 → A1 没抢回来

---

## 6. 不要做（已被你们自己的 A/B 证伪）

| 方案 | 实测结果 | 结论 |
|---|---|---|
| 继续降/关卡片阴影 | 全关 12.3 fps，保留（20px）14.3 fps | 更慢，别再动 |
| 关掉 `_UncoveredPageClipper` | 11.5 fps，UI 仍 34 ms | 无效 |
| 拖动时关掉地图 touch 转发 | 10.3–11.3 fps | 无效（但去重有效，见 A4） |
| 翻页期冻结地图纹理 | 平均 50.8 vs 52.9 ms | 无效，且地图区空白 |
| 关 Impeller 用 Skia | 冷启动 2964 vs 2908 ms | 噪声内，且 opt-out 已弃用 |
| 翻页期间不画阴影 | 平均 55.6 ms vs 39.2 ms | 更慢（`moving` 翻转整页重建） |

---

## 7. 排期建议

| 迭代 | 内容 | 工期 | 出包验收 |
|---|---|---|---|
| 迭代 1 | A1 + A2 + A3 + A4 + C1 | 3–4 天 | 翻页 p50 目标 ≤25 ms，地图呈现 ≥16 fps，无"导航卡不动" |
| 迭代 2 | B3 + B2 + B1(v1) | 4–5 天 | 翻页 p50 ≤20 ms，卡片重绘 <1 ms |
| 迭代 3 | B1(v2) + C4 | 3–4 天 | 翻页 p50 ≤16.7 ms，80% 帧 ≤20 ms |
| 迭代 4 | C2 + C5（可选） | 2–3 天 | PSS −10~20 MB，回桌面 −1 s |

每轮都留「性能模式/画质模式」开关（glass 与 lift 动效都可配置），任何一项在实车上不达标就单独回滚，不打包回退。

---

## 8. 风险登记

| 风险 | 影响 | 缓解 |
|---|---|---|
| A2 改默认动效被用户视为"缩水" | 观感 | 保留 `slide` 可选；设置里标明"滑动（高负载）/ 浮起（推荐）" |
| B1 快照显存（3×8.3 MB） | PSS +25 MB | 只保留当前+相邻；`onTrimMemory` 立即 dispose |
| B1 快照与地图 Texture 层不一致 | 视觉闪 | v1 含地图卡时不快照；v2 用 Texture 叠层并对齐裁剪 |
| B2 预烘焙图被样式切换遗漏 | 视觉错 | 缓存键包含全部样式字段；样式变化时整体 `clear()` |
| A1 看护轮询耗电 | 静态功耗 | `ready` 后降到 1.5 s，页面不可见即停 |
| C5 引擎常驻挤占内存 | 与地图/媒体抢内存 | 只在 ≥3 GB 车型开启；`onTrimMemory` 释放 |
