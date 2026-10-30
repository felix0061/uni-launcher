# 君君桌面为什么比 UNI桌面流畅：逐项归因

> 对比对象
> - **君君桌面** `com.ecarx.qq.tool` 1.0.01280：纯原生 Java + Android View（HWUI 渲染），system uid / platform 签名
> - **UNI桌面** `xyz.i4o.uni.launcher`：Flutter（Skia/Impeller，自绘 SurfaceView）+ 原生适配层
>
> 本文的 UNI 侧数字全部来自项目自己的实车测量记录：`docs/PERFORMANCE_PLAN_0_6_19.md` §8/§15/§16、`docs/PERFORMANCE_0_6_18.md`、`docs/PERFORMANCE_0_6_11.md`。君君桌面侧标注为【码】的是从反编译产物里读到的实现事实。
>
> **一句话结论**：不是"谁的代码写得好"，而是**两套渲染模型在 2016 年 GPU 上的差距**。君君桌面每帧只重记录少数变化的 RenderNode，动画期间把内容提升成硬件层只做矩阵变换、毛玻璃是**一次性截图后的静态位图**、地图是**独立图层不进桌面重绘**；UNI桌面每帧要走 Dart build → layout → paint → raster，翻页时**每帧重录并重光栅两张 1920×1080 页面**（每页 8.3 MB，超过引擎光栅缓存预算），地图每一帧都会让卡片图层失效。

---

## 0. 归因总表（按影响排序）

| # | 原因 | 君君桌面 | UNI桌面 | 证据强度 |
|---|---|---|---|---|
| 1 | 翻页时每帧工作量 | 只改 `alpha` / `translationY` / `scale` 三个 RenderNode 属性（600 ms），**入场页先 bringToFront，动画期间冻结毛玻璃**；内容一次都不重录 | 每帧重录两张整页 + 重新光栅，UI 33–39 ms + raster 24–37 ms = 12–15 fps | **实测**（UNI 侧 A/B 已排除阴影/裁剪/触摸/丢帧四个假设） |
| 2 | 渲染模型 | HWUI：RenderNode 树按脏节点重记录，未变的节点复用 | Flutter：build→layout→paint→raster 全链路，依赖光栅缓存，超预算即全重画 | **实测**（§16.3 唯一自洽解释） |
| 3 | 毛玻璃 | `BlurScrimFrame` 一次性截图 + 静态 `frosted` Bitmap 复用；`GlassLayout` 自带 `cache` Bitmap + `frozen` 冻结 | 每卡一个 `BackdropFilter.grouped(ImageFilter.blur(10,10))`，要读回背景做两遍高斯 | **码** + 实测（UNI 判定为"最贵单类操作"） |
| 4 | 卡片阴影/裁剪 | 缓存位图 + 单层 drawable；必要时硬件层 | 每卡 37 px 高斯 BoxShadow + **双层** `ClipRRect`，数据一变整层重光栅 | **实测**（阴影 44→20 换来翻页 p90 99.9→66.6 ms） |
| 5 | 地图层级 | `ActivityView` 内部 `SurfaceView` = 独立图层，SurfaceFlinger 直接合成，**不参与桌面 View 重绘** | 地图是 Flutter 纹理，地图每来一帧让卡片图层失效；实测**只呈现了生产端一半的帧**（22.1 fps 生产 / 11.8–13.3 fps 呈现） | **实测** + **码** |
| 6 | 数据链路 | 同一进程直接 `setText`/`invalidate` | method channel + JSON 快照（0.6.18 前 805 KB/包）→ 主线程扇出 3 个引擎 → Dart `jsonDecode` + 全树重建 | **实测**（805 KB: 8.4 ms 编码 / 3.5 ms 解析；增量包 694 B） |
| 7 | 文字排版 | `TextView` + `MarqueeHelper` 用 `translationX` 跑马灯，必要时才升硬件层 | 每帧中文排版（"文字整形是全帧最贵的一步"），已用 `TextPainter` 缓存缓解 | **实测** + **码** |
| 8 | 引擎/线程/内存 | 单 Activity、单 View 树；PSS 量级原厂桌面 60–102 MB | 3 个 `FlutterEngine`（主/底栏/面板）各带 raster 线程与 Dart 堆；PSS 112–235 MB，Graphics 147 MB 主要是地图 | **实测** |
| 9 | 系统身份 | system uid + HOME 常驻 + 可预热，调度权重更友好 | 普通应用（虽有平台签名），进程冷启动即完整引擎初始化 | 推断 |
| 10 | 全屏缩放层 | `DesignCanvas` 只做容器级 transform | `FittedBox` 1600→1920 恒等 1.2× 全树缩放 | **码**（UNI 列为 P2，改它要动验收口径） |

---

## 1. 先把口径对齐：这是同一台车上的对比吗

两个 APK 的判据都指向同一档硬件：

```java
// 君君桌面 DesktopLayoutSettings.is820A()
densityDpi <= 160 && Math.max(widthPixels, heightPixels) >= 1800
// UNI 实车：MSM8996 / Adreno 530 / Android 9 / 1920×1080 / density 160  → 也命中
```

也就是说这台车同时满足君君桌面的"820A 分支"和 UNI 的目标平台。**如果两者确实装在同一台车上，"更流畅"就不是硬件差异**（如果君君桌面只装在别的高配车型上，那先排除硬件这一项）。

**测量口径不能混**：君君桌面是 HWUI 应用，`dumpsys gfxinfo` 直接给帧耗时；UNI桌面在自己的 `1.raster` 线程绘制到 SurfaceView，`gfxinfo` 在 Android 9 上对 Flutter 永远读 0 帧（项目已踩过），只能用 `dumpsys SurfaceFlinger --latency '<图层>'` 反推呈现间隔。所以"丝滑"这个感受是对的，但两边的数字不同源。

---

## 2. 原因 1+2：翻页时每帧要做多少事（最大差距）

### UNI 侧（实测，已经是项目自己的结论）

```
持续拖动 2.5s（同一页）：
UI 线程 31–46 ms/帧 + raster 线程 24–33 ms/帧 = 55–75 ms/帧  → 12–15 fps
```

四个假设全部被同车同源 A/B **证伪**：

| 假设 | 改动 | 结果 |
|---|---|---|
| 阴影太重 | 全关 | 12.3 fps（原 14.3），更慢 |
| 出页每帧重裁剪 | 关掉 `_UncoveredPageClipper` | 11.5 fps，UI 仍 34 ms |
| 拖动时每个 move 注入虚拟屏（≈300 次 IPC） | `touch` 直接 return | 10.3–11.3 fps |
| 地图送帧导致图层失效 | 翻页期冻结纹理 | 平均 50.8 ms vs 52.9 ms |

唯一自洽的解释（§16.3）：**每帧固定成本 = 重录两张 1920×1080 页面的绘制指令（UI 33–39 ms）+ 合成它们（raster 24–37 ms）**；两页各 8.3 MB，超过引擎光栅缓存预算，所以缓存图层每帧都被丢弃，只能重录重光栅。

翻页的包装层数（`widgets/page_transition.dart`）：

```
ClipRect(:215) → _PageTransform(:230) → RepaintBoundary(:241) → ClipRect(:242) → 页面
_PageTransform: ClipRect(:288) → Transform.translate(:298) → Transform.scale(:302) → Opacity(:304)
```

`_UncoveredPageClipper.shouldReclip` 恒 `true`（:318），出页每帧重新计算裁剪。

### 君君桌面侧（【码】）

真正切页的代码在 `SceneDesktop.show(int, boolean)`（:3057）：

```java
View[] viewArr = {sceneCanvas, navPage, musicCanvas};        // 三页，全部常驻
raisePage(viewArr[i3]);                                     // ★ 入场页 bringToFront，避免两页混合
GlassLayout.setFrozen(true);                                // ★ 动画期间冻结所有卡片毛玻璃
MAIN.postDelayed(unfreezePageGlass, 720L);
slidePage(viewArr[i4], i4, false, z4 ? -60f : 60f, i5);      // 出场页
slidePage(viewArr[i3], i3,  true,  z4 ? 60f : -60f, i5);     // 入场页
```

而 `slidePage`（:3178）只动三个便宜属性，时长 600 ms：

```java
ObjectAnimator.ofFloat(view, View.ALPHA,          alpha, f4);      // 0 ↔ 1
ObjectAnimator.ofFloat(view, View.TRANSLATION_Y,  translationY, f3); // ±60dp → 0
ObjectAnimator.ofFloat(view, View.SCALE_X,        scaleX, f5);      // 0.98 ↔ 1.0
```

三个关键设计：

1. **不是横向整页平移**。UNI 的"平移"要两页各 1920 宽同时可见、逐帧重录；君君桌面是**淡入+上浮 60dp+0.98→1.0 缩放**，入场页先 `bringToFront`，画面里始终只有一页是"主体"，位移只有 60dp —— 抖动在 600 ms 的淡入里几乎看不出来。
2. **`alpha/translationY/scale` 都是 RenderNode 属性**，HWUI 只更新矩阵和 alpha，**子 View 的绘制指令一条都不重录**，GPU 直接复用上次的 RenderNode。
3. **`GlassLayout.setFrozen(true)`**：动画期间不再重算卡片玻璃，直接用缓存位图，720 ms 后解冻。这是"翻页时把最贵的模糊关掉"的成品实现。

另外面板滑动前也会先 `holdBackdrop(true)` 把背景层 `setLayerType(2 /* HARDWARE */)` 提成硬件层，再 `animate().translationY()`（`DesignPages.java:1684`）——同一套路。

**这正是 UNI 自己在 §16.4 得出的唯一可行路径**：

> 手势开始时把两页各自光栅进一张 `ui.Image`，动画期间只位移两张纹理。每帧成本降到 2 次纹理绘制（约 2–4 ms），40–60 fps 可达。

君君桌面不需要发明这个，因为它用的就是系统现成机制（RenderNode + 硬件层 + 冻结缓存），而且**连"动画期关掉毛玻璃"都做了**。这是两者最大的结构性差距。

---

## 3. 原因 3+4：毛玻璃与阴影——一个用静态位图，一个每帧真算

### 君君桌面（【码】）

```java
// BlurScrimFrame.java:39-45, 静态字段
private static int frostW, frostH;
private static Bitmap frosted;                 // 全局只有一张模糊图
public static void captureDesktop(View view)   // 打开面板时截一次桌面
...
// DesignCanvas.java:367-368  onDraw 里只做一次 blit
((BlurScrimFrame) childAt).drawFrost(canvas, getWidth(), getHeight());

// GlassLayout.java:35,100-116  卡片玻璃背景自带缓存位图 + 冻结开关
private Bitmap cache;
if (!this.frozen || (bitmap = this.cache) == null || bitmap.isRecycled()) { ...重建... }
// :205 drawLocal() 里只 drawBitmap
```

结论：**"毛玻璃"是打开面板时做一次（截屏+模糊），之后每帧只 blit 一张位图**；卡片玻璃也是同一个套路 + `frozen` 冻结。

### UNI 侧（【码】+ 实测）

```dart
// widgets/glass_surface.dart:86-92
glass ? BackdropFilter.grouped(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))
// widgets/launcher_dialog.dart:124 对话框同样一层
```

`BackdropFilter` 需要把已绘制的背景**读回**、做两遍高斯、再合成——`Adreno 530` 上这是最贵的一类操作，而一屏有 8–10 张卡。项目自己已判定"glass 模式下整帧 −10 ms 以上"，但因为是视觉取舍所以没动。

阴影：UNI 每卡 `BoxShadow(blur = Design.px(44) ≈ 37px)` + 外层 `ClipRRect`（只为让阴影贴合圆角）+ 内层再加一层裁剪（`glass_surface.dart:73-91`，计划 §2.3 已定位"双层裁剪"）。君君桌面是缓存位图/单层 drawable，且卡片内容变化靠脏区重绘而不是整层重光栅。

实测证明阴影确实贵：**44→20 换来翻页 p90 99.9 → 66.6 ms（约 25%）**；但继续降到 0 反而更慢（12.3 fps）——因为瓶颈不是笔刷成本而是"每帧要重画的面积"，这一点和君君桌面的实现路径正好互补。

---

## 4. 原因 5：地图在图层的哪个位置

| | 君君桌面 | UNI桌面 |
|---|---|---|
| 承载 | `ActivityView` 内部 `SurfaceView` | Flutter `Texture`（`SurfaceTexture` 来自自建 `VirtualDisplay`） |
| 合成 | SurfaceFlinger 直接合成**独立图层**，桌面 View 重绘时它不受影响 | 进入 Flutter 合成树，**地图每来一帧就让卡片所在图层失效** |
| 实测 | — | 高德生产 22.1 fps，窗口只呈现 11.8–13.3 fps，**一半的帧被丢掉** |
| 代价 | 需要处理层序/圆角/挖洞（第一章那套） | 圆角/动画免费，但每帧参与合成 |
| 空闲 CPU | — | 含地图页 34.8%（地图每帧消耗 12.5 帧），无地图页 13.9% |

这是"流畅感"里最直观的一条：**导航画面跟不跟手**。君君桌面的地图由系统合成，桌面 UI 再忙也不会拖累地图出帧；UNI 的地图与 UI 在同一条 Flutter 合成链上，UI 一忙（翻页 178% CPU）地图就跟着掉。

---

## 5. 原因 6+7+8：数据链路、文字、引擎数量

- **数据链路**：君君桌面改一个字段 = 同进程 `setText` + 一个小区域 `invalidate`。UNI 每次状态变化要走 method channel + JSON（0.6.18 前 805 KB/包，编码 8.4 ms + 解析 3.5 ms，且三个窗口各做一次）→ Dart 侧 `jsonDecode` + `MaterialApp` 全树重建。0.6.18 已把高频包压到 694 B，但**"点一下顿一下"的体感来自这里**，与帧率是两条不同的轴。
- **文字**：君君桌面 `TextView` 排版一次，跑马灯用 `MarqueeHelper` 的 `translationX` 动画（必要时 `setLayerType(0/2)` 切换），不重排。Flutter 侧中文整形是全帧最贵的一步（UNI 已缓存 `TextPainter`，但卡片重建仍会重排）。
- **引擎**：君君桌面一个 Activity 一棵 View 树；UNI 有 3 个 `FlutterEngine`（主界面 / 底栏 / 面板），各自一套 Dart 堆 + raster 线程，PSS 112–235 MB，Graphics 最高 147 MB（主要是地图虚拟显示缓冲）。
- **全屏缩放**：UNI 的 `LauncherShell` 用 `FittedBox` 把 1600 设计画布放大到 1920（1.2×），整棵树被缩放；君君桌面的 `DesignCanvas` 只在容器级做 transform，实际绘制尺寸就是最终尺寸。

---

## 6. 系统身份这一层（不可忽略）

君君桌面是 `sharedUserId="android.uid.system"` + platform 签名 + 默认 HOME：
- 可常驻、可预热、可主动拉起/保持关键进程；
- `ActivityManager`/`InputManager` 的隐藏接口随便用（详见同目录 `NAV_EMBED_COMPARISON.md`）；
- 它的桌面 Activity 本身就是系统 HOME，回桌面不重建（UNI 的 P2 项"Home 常驻"正是这条）。

UNI 是普通应用（虽用平台签名做覆盖安装），每次冷启动都要完整初始化 Flutter 引擎：**冷启动 2521 ms 中约 2 s 是引擎+首帧**，从 3054 ms 优化到 2521 ms 已经是应用侧极限。

---

## 7. 要"拉平体感"，按性价比排序

| 优先级 | 动作 | 依据 | 预期 |
|---|---|---|---|
| P0 | **翻页改页级纹理位移**：手势开始把两页各光栅成 `ui.Image`，动画期只 `drawImageRect` | §16.4 已算出这是达到 40 fps 的唯一路径 | UI 33–39 → 数 ms，raster 24–37 → 2–4 ms |
| P0 | **或改翻页形态**（更便宜的一步）：淡入 + 60dp 上浮 + 0.98→1.0 缩放，入场页先置顶，动画期冻结 glass | 君君桌面 `SceneDesktop.show()` 的成品做法；位移量从整屏宽降到 60dp | 需要重录的面积与时长同时下降，抖动在淡入里不可见 |
| P0 | **修"内嵌地图被高德抢回前台"**：`mCurrentFocus` 跳走导致地图卡 0 fps 死图 | §9.4 实测 | 直接消除"导航卡有时候不动" |
| P1 | **卡片背景预烘焙**（阴影+填充+边框 → `ui.Image`，按尺寸缓存） | 计划 §2.2 | 单卡重绘 8–15 ms → <1 ms（估） |
| P1 | **glass 降级**：模糊只留对话框/底栏，卡片改半透明+噪点；给"性能/画质"开关 | 计划 §2.5 | glass 模式整帧 −10 ms（估） |
| P1 | **去掉双层 `ClipRRect`** + 去水波（`NoSplash`） | 计划 §2.3 / §2.4 | 每卡每帧省一次 clip；点击反馈 −2~5 ms（估） |
| P2 | **相邻页空闲预光栅** | §11 / §16.4 | 消除入场页首帧 100–166 ms 长帧 |
| P2 | **Impeller 四组 A/B**（`vulkan` / `opengles` / `+lazy-shader` / `+antialias-lines=false`） | 计划 §3.1，Adreno 530 是 2016 年 Vulkan 1.0 驱动 | 未知，可能整体 ±20% |
| P2 | **面板复用底栏引擎**（少一个引擎/raster 线程） | 计划 §3.4 | −10~20 MB、少一个 raster 线程 |
| P2 | **去全屏 `FittedBox` 1.2×** | 计划 §4 | 文本/图标不再重采样（要改验收口径） |

上面九项里，UNI 项目自己的性能计划已经写了 7 项，**缺的就是第 1 项（页级纹理）和第 2 项（地图焦点）**——这两项正是与君君桌面差距最大的两处。

---

## 8. 怎么验证（同车、同口径）

```bash
# 0) 确认同一台车
adb shell getprop ro.product.model; adb shell getprop ro.build.version.sdk; adb shell wm size; adb shell wm density

# 1) 君君桌面（HWUI，能直接用 gfxinfo）
adb shell dumpsys gfxinfo com.ecarx.qq.tool reset
# 滑动 4 次
adb shell dumpsys gfxinfo com.ecarx.qq.tool framestats | grep -E 'Janky frames|90th|95th'

# 2) UNI桌面（Flutter 自绘，gfxinfo 恒 0，只能看呈现间隔）
adb shell dumpsys SurfaceFlinger --latency "$(adb shell dumpsys SurfaceFlinger --list | grep -i uni | head -1)"

# 3) 谁在吃 CPU（翻页时对比）
adb shell top -H -p $(adb shell pidof xyz.i4o.uni.launcher)
adb shell top -H -p $(adb shell pidof com.ecarx.qq.tool)

# 4) 地图是否被抢前台（UNI 的 P0）
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'
```

判读：
- 君君桌面 `gfxinfo` 的 `90th percentile` 若在 20 ms 以内，说明它确实按 HWUI 节奏在 60 fps 附近；
- UNI 的呈现间隔若是 16.7/33.3 交替（约 40 fps 上限）→ 说明瓶颈仍是"入场页整页光栅"，页级纹理做完应该变成连续 16.6；
- 若 UNI 呈现间隔出现 100 ms 以上的尾帧且伴随 `taskMoves` 增加 → 命中地图被抢前台。

---

## 9. 一句话总结

君君桌面流畅，不是因为它的动画更好看，而是因为它**几乎不做"每帧重画整屏"这件事**：
1. 翻页 = 只改三个 RenderNode 属性（alpha / translationY / scale），入场页先置顶，动画期冻结毛玻璃，内容一次不重录；
2. 毛玻璃 = 一次截图后的静态位图（`BlurScrimFrame`）+ 卡片缓存位图（`GlassLayout.cache/frozen`）；
3. 卡片 = 缓存背景 + 脏区重绘；
4. 地图 = 独立图层（`ActivityView` 的 `SurfaceView`），不参与桌面重绘；
5. 数据 = 同进程直接改 View，没有 JSON 快照与跨引擎扇出。

UNI 现在这五条里，第 4 条是主动选择（换来圆角/动画自由），第 1、2、3 条才是真正的性能欠账——而且项目自己的实测已经把账算清楚了：**UI 33–39 ms + raster 24–37 ms，等于每帧超预算 4 倍**。

UNI 现在这五条里，第 4 条是主动选择（换来圆角/动画自由），第 1、2、3 条才是真正的性能欠账——而且项目自己的实测已经把账算清楚了：**UI 33–39 ms + raster 24–37 ms，等于每帧超预算 4 倍**。
