# UNI Launcher 0.4.0 · Flutter Android

包名 `xyz.i4o.uni.launcher`，面向领克 05 IP753 / Android 9。界面由 Flutter 绘制，Android 平台通道复用已有 Java 适配器。源代码直接保存在本目录并由仓库的本地 Git commit 管理，不另行打包源码。

## 0.4.0 接入补充

- 导航卡片使用 Android 9 ActivityView 容器显示实际导航应用，支持关联应用、嵌入开关、全屏和失败回退。普通权限模拟器只验证降级，真高德嵌入仍待车机授权与实测。
- 可关联已安装的网易云、QQ、原车音乐等播放器。读取及控制绑定同一应用会话，增加封面和可用操作判断；无会话不控制其他播放器。
- 车辆增加后台限频的 ECARX 候选只读通道和新鲜度校验，展示温度、风量、模式、三项座椅及四轮原始胎压；真实写操作仍禁用。
- 38 类矢量天气图标，昼夜和未知状态由公共组件处理；原厂天气数据接口仍待核对。
- 完整差距、证据和上车条件见[官方能力对照](../docs/OEM_PARITY_0_4.md)。

## 界面与设置

- 无左侧栏；80 逻辑像素底栏按「首页、全部、空调操作、音乐控制、音乐信息、车辆信息、360」排列，操作按钮使用图标。
- 长按首页进入设置；深色、浅色、跟随系统，5 组主题色、自定义取色器与行内 HEX。
- 圆角 0–40，提供滑杆和数值输入，0 为直角。毛玻璃独立开关，默认关闭；关闭时移除所有 `BackdropFilter`，保留半透明材质。设置与卡片布局保存到 Android SharedPreferences。
- 切换动效页可选无动画、淡入淡出、横向滑动，支持左右轻扫，底栏固定；默认无动画。
- 音乐卡片、底栏和详情复用滚动歌词，有时间轴时按媒体进度同步，支持暂停与 seek；无歌词不沿用旧曲目。来源与边界见[歌词接入说明](../docs/MEDIA_LYRICS_AND_MOTION.md)。
- 卡片长按编辑、网格移动、缩放、重命名、删除/撤销、取消/完成、添加与分页；尺寸按内容设最小值，最多 20 页。
- 覆盖官方目录中的导航、媒体、天气、日历、账号、清理、胎压、可选空气质量；其他车型的出行服务保留目录记录但不出现在 IP753 卡片库。

## 样式核对与座椅

此次按[设计一致性审计](../docs/UI_FIDELITY_AUDIT.md)修正默认胶囊按钮、坐标换算、完整桌面预览、原始 SVG 图标、卡片内容结构、分类卡片库、单卡尺寸设置及所有面板。`Design.px` 明确 1920 稿件到 1600 逻辑画布的换算，按钮采用圆角矩形，圆形色点保留语义形状。

空调面板增加主驾加热/通风、副驾加热，显式选择关闭/1/2/3档。演示中主驾加热与通风互斥；实车档位和互斥契约尚未确认。每项座椅控制分别检查自己的 capability，普通空调写权限不启用座椅控制；实车数据未知时显示 `—` 并禁用操作。

`python3 tools/sync_design_assets.py` 从本仓库原创设计符号同步 SVG 资源；Flutter 使用 `flutter_svg` 绘制，仍无 WebView。新增卡片、编辑器、气候面板、座椅和统一弹层模块各自复用公共主题与表面。

## 模块

| 路径 | 职责 |
| --- | --- |
| `lib/model/` | 外观偏好、卡片规格、网格约束和布局序列化 |
| `lib/controller/` | 状态订阅、编辑事务、撤销与持久化 |
| `lib/theme/`、`lib/widgets/glass_surface.dart` | 颜色 token、圆角、可选模糊与复用表面/图标按钮 |
| `lib/widgets/` | 卡片内容、可编辑容器、底栏和功能面板 |
| `lib/screens/` | 首页、桌面设置 |
| `lib/platform/` | `NativeGateway` 接口、MethodChannel / EventChannel |
| `android/app/src/main/java/.../MainActivity.java` | FlutterActivity、生命周期、限定命令与状态桥接 |
| `../android/src/.../core`、`integration` | 共用 Java 应用列表、媒体、车辆、导航栏和原厂 Widget 宿主 |
| `../analysis/official-widgets.json` | 共用原厂提供者目录，Gradle 构建时同步到 assets |
| `test/`、`integration_test/` | 状态/组件测试与 Android 9 真模拟器交互测试 |

正常界面不显示 Binder、权限异常或属性 ID；功能接入页提供来源和可用状态。Flutter 入口不编译旧 WebView MainActivity、离线 HTML 或 JS 界面。

## 实车接入边界

实车默认关闭模拟数据，未接通数据为 `—`，对应控制禁用；模拟器可演示空调和媒体，演示操作不会控制车辆。平台能力沿用[官方 APK 证据](../docs/APK_ANALYSIS.md)，嘟嘟仅作辅助参考。

- 已接入 Android 的应用列表/图标/启动、媒体会话状态与控制、原厂 Widget 兼容页、窗口导航栏隐藏，以及需系统授权的全局隐藏。媒体会话与原车媒体中心同源同值仍待实车比对。
- 车辆适配器保留官方 `Car.create → getICarFunction → getFunctionValue` 只读探测。当前不具备本车完整空调写契约，实车空调写命令返回不可用；演示温度回读不是实车验收。
- 统一风格的天气、账号、日历、清理、胎压、AQI 卡片仍待 Provider APK/实车字段验证；提供打开原厂 Widget/应用的兼容路径。原厂 RemoteViews 自身样式不由 Flutter 任意重绘。
- 演示路线只用于无原生导航状态的界面预览；实际 Android 首页使用导航容器或明确的全屏回退。真高德嵌入、实时摘要、倒车接管、休眠恢复、窗口边界及长时性能待实车验证。

## 构建

本机验证工具链：Flutter 3.47.8 / Dart 3.13.7、Java 17、Android SDK 36。Android 最低 API 24，目标 API 28，维持当前车机行为；不用于商店发布。工程的签名配置使用仓库外的本地开发 keystore，与早期版本一致，便于覆盖安装。可用 `UNI_SIGNING_STORE` 覆盖路径，私钥不入库。

```sh
cd app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --target-platform android-arm64,android-x64 --split-per-abi
```

构建产物在 `build/app/outputs/flutter-apk/`。`app-arm64-v8a-release.apk` 是后续车机验证候选，`app-x86_64-release.apk` 供模拟器；这两个 ABI 构建自相同源码，arm64 尚未经过实车运行验证。

分 ABI APK 的 versionCode 由 Flutter 添加 ABI 前缀，本次 arm64 为 2004、x86_64 为 4004；后续升级应提高 `pubspec.yaml` 的构建号。当前签名、大小和 SHA-256 记录于[构建报告](verification/build-report.json)。

本机 Flutter SDK 位于 `/data/tools/flutter`、Android SDK 位于 `/data/tools/linkco-android/sdk`。需要本地代理环境时可用 `python3 tools/flutter_task.py <flutter 参数>`；脚本为 Gradle 继承已有代理，测试连接本机 VM service 时绕过代理。可用 `FLUTTER_SDK` 覆盖 Flutter 路径。SDK、Gradle 缓存和 build 均不提交。

## 验证

启动已有 API 28 / 1920×1080 横屏模拟器（配置见[基线模拟器说明](../android/README.md)）后：

```sh
python3 tools/flutter_task.py drive \
  --driver=test_driver/driver.dart \
  --target=integration_test/launcher_test.dart \
  --debug -d emulator-5580
```

测试使用模拟空调及两个独立的合成播放器；会重置这个模拟器内 UNI 的主题/布局、调整演示和导航栏开关。执行前应指定模拟器，不把测试脚本用于实车。

切换 release 构建与集成测试时保留默认 pub 步骤，以重新生成包含开发测试插件的注册代码；不要在这种切换后直接使用 `drive --no-pub`。

组件测试覆盖默认无模糊、开关与原生保存、深浅主题/0 圆角、布局冲突/边界、取消/恢复、最小卡片尺寸、未连接状态。Android 集成测试覆盖真实应用列表平台通道、底栏顺序、首页长按、主题/模糊持久化、触摸拖动缩放、演示空调回读与导航栏开关。

歌词集成测试需先在模拟器安装合成媒体源，不能安装到车机：

```sh
python3 ../android/tools/build-fixture.py
python3 tools/flutter_task.py drive --driver=test_driver/driver.dart --target=integration_test/launcher_test.dart -d emulator-5580
```

驱动脚本在 Flutter 安装完成后准备模拟器媒体授权与前台测试音源，校验设备为模拟器；测试源可分别卸载 `ecarx.xsf.mediacenter` 和 `xyz.i4o.uni.fixture.player`。

[验证报告](verification/emulator-report.json)和同目录的 `flutter-*.png` 是实际模拟器输出。只验证功能，不把模拟器帧率视为 MSM8996 实车性能。后续按[实车验收记录](../docs/CAR_ACCEPTANCE.md)继续核对。

最终静态分析、状态/组件测试、Android 9 集成与 release 验证结果见[构建报告](verification/build-report.json)。实际 release [首页](verification/flutter-release-home.png)与[设置](verification/flutter-release-settings.png)截图单独保存；实时车控和性能仍待实车。
