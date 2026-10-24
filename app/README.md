# UNI Launcher 0.2.0 · Flutter Android

包名 `xyz.i4o.uni.launcher`，面向领克 05 IP753 / Android 9。界面由 Flutter 绘制，Android 平台通道复用已有 Java 适配器。源代码直接保存在本目录并由仓库的本地 Git commit 管理，不另行打包源码。

## 界面与设置

- 无左侧栏；80 逻辑像素底栏按「首页、全部、空调操作、音乐控制、音乐信息、车辆信息、360」排列，操作按钮使用图标。
- 长按首页进入设置；深色、浅色、跟随系统，5 组主题色和自定义 HEX。
- 圆角 0–40，0 为直角。毛玻璃独立开关，默认关闭；关闭时移除所有 `BackdropFilter`，保留半透明材质。设置与卡片布局保存到 Android SharedPreferences。
- 卡片长按编辑、网格移动、缩放、重命名、删除/撤销、取消/完成、添加与分页；尺寸按内容设最小值，最多 20 页。
- 覆盖官方目录中的导航、媒体、天气、日历、账号、清理、胎压、可选空气质量；其他车型的出行服务保留目录记录但不出现在 IP753 卡片库。

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
- 导航图为明确标注的演示；实时摘要、地图嵌入、倒车接管、休眠恢复、窗口边界及长时性能待实车验证。

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

分 ABI APK 的 versionCode 由 Flutter 添加 ABI 前缀，本次 arm64 为 2002、x86_64 为 4002；后续升级应提高 `pubspec.yaml` 的构建号。当前签名、大小和 SHA-256 记录于[构建报告](verification/build-report.json)。

本机 Flutter SDK 位于 `/data/tools/flutter`、Android SDK 位于 `/data/tools/linkco-android/sdk`。需要本地代理环境时可用 `python3 tools/flutter_task.py <flutter 参数>`；脚本为 Gradle 继承已有代理，测试连接本机 VM service 时绕过代理。可用 `FLUTTER_SDK` 覆盖 Flutter 路径。SDK、Gradle 缓存和 build 均不提交。

## 验证

启动已有 API 28 / 1920×1080 横屏模拟器（配置见[基线模拟器说明](../android/README.md)）后：

```sh
python3 tools/flutter_task.py drive \
  --driver=test_driver/driver.dart \
  --target=integration_test/launcher_test.dart \
  --debug -d emulator-5580
```

测试只使用模拟空调动作；会重置这个模拟器内 UNI 的主题/布局、调整演示和导航栏开关。执行前应指定模拟器，不把测试脚本用于实车。

切换 release 构建与集成测试时保留默认 pub 步骤，以重新生成包含开发测试插件的注册代码；不要在这种切换后直接使用 `drive --no-pub`。

组件测试覆盖默认无模糊、开关与原生保存、深浅主题/0 圆角、布局冲突/边界、取消/恢复、最小卡片尺寸、未连接状态。Android 集成测试覆盖真实应用列表平台通道、底栏顺序、首页长按、主题/模糊持久化、触摸拖动缩放、演示空调回读与导航栏开关。

[验证报告](verification/emulator-report.json)和同目录的 `flutter-*.png` 是实际模拟器输出。只验证功能，不把模拟器帧率视为 MSM8996 实车性能。后续按[实车验收记录](../docs/CAR_ACCEPTANCE.md)继续核对。

本次结果：静态分析无问题，15 项状态/组件测试及 22 项 Android 9 集成检查通过；release 签名与 ABI 校验通过，x86_64 release 安装、启动、HOME Intent 和长按首页进入设置均已验证。实际 release [首页](verification/flutter-release-home.png)与[设置](verification/flutter-release-settings.png)截图已检查。
