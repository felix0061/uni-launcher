# UNI 桌面

面向领克 05 PHEV 原车 IP753 车机的 Android 桌面。界面使用 Flutter 构建，通过 Android 原生适配层接入导航、媒体和车辆信息；应用包名为 `xyz.i4o.uni.launcher`。

## 功能

- 卡片式桌面：支持分页、拖动、缩放和布局保存，提供导航、音乐、天气、车辆信息等卡片。
- 外观：提供深浅色、深蓝玻璃主题、自定义主题色、圆角和壁纸设置。
- 导航与媒体：支持关联导航和音乐应用，显示歌词及真实音频频谱；全局底栏提供媒体和车辆相关操作。
- 车辆接入：参考原车 Launcher 的接口读取和控制支持的车辆功能，具体能力以车机权限和实车验证结果为准。

红绿灯卡片支持已核对的高德广播；百度、腾讯地图的多方向数据出口仍在研究。各项能力和验证边界详见[更新日志](CHANGELOG.md)及[红绿灯接入记录](docs/TRAFFIC_LIGHT_PROVIDERS.md)。

## 运行环境

- 目标车机：领克 05 PHEV，IP753，Android 9（API 28）；其他车型或车机版本的兼容性尚未验证。
- 开发环境：Flutter、Android SDK、Java 17；Android 最低 API 24。已验证的工具链及详细配置见 [Flutter 工程说明](app/README.md)。
- 应用当前版本以 [pubspec.yaml](app/pubspec.yaml) 为准。模拟器验证不能替代车机功能和性能验证。

## 获取与构建

在仓库根目录执行：

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64,android-x64 --split-per-abi
```

构建产物位于 `app/build/app/outputs/flutter-apk/`：arm64 包用于 ARM 设备，x86_64 包用于模拟器。普通构建使用本地开发签名；IP753 测试包使用单独签名，同签名的版本才能覆盖安装。签名文件不包含在仓库中。构建和签名细节见 [Flutter 工程说明](app/README.md) 与对应[版本记录](CHANGELOG.md)。

## 使用

在桌面右上角点击设置图标，或长按首页进入桌面设置；长按卡片可调整桌面布局。导航应用、播放器和底栏选项可在桌面设置中配置。部分车辆、地图及频谱功能依赖相应系统权限、应用支持和设备能力。

## 项目结构

| 目录 | 内容 |
| --- | --- |
| `app/` | Flutter 界面、Android 应用入口和测试 |
| `android/` | 原生适配模块及早期实现参考 |
| `docs/` | 设计、接口、版本验证与实车记录 |
| `design/` | 设计稿及交互原型 |
| `analysis/` | APK 分析摘要与证据索引 |
| `tools/` | 分析、构建与验证辅助工具 |

## 文档

- [更新日志](CHANGELOG.md)与[实车验收记录](docs/CAR_ACCEPTANCE.md)
- [Flutter 工程说明](app/README.md)与[原车车辆接口](docs/OFFICIAL_CAR_API.md)
- [导航与红绿灯](docs/AMAP_TRAFFIC_LIGHT_CARD.md)、[媒体歌词与动效](docs/MEDIA_LYRICS_AND_MOTION.md)
- [产品与界面设计](docs/PRODUCT_DESIGN.md)、[车辆卡片设计](docs/VEHICLE_CARD_DESIGN.md)
- [完整参考资料与历史设计](docs/PROJECT_REFERENCE.md)

## 免费使用与许可声明

UNI 桌面免费提供。本项目由权利人发布的原创代码及资源，按照以下**非商业、源码可用、相同条款共享**的自定义许可提供：

- 允许个人和组织为非商业目的免费使用、复制、研究、修改和分享本项目。
- 未经相关权利人事先书面授权，禁止将本项目及其修改版用于商业目的或收费，包括销售软件、收取安装或定制费用、付费分发，以及将其用于收费产品或服务。
- 分发本项目或其修改版（包括 APK）时，必须免费向接收者提供与该版本对应的完整、可修改源代码，保留原有版权与许可声明，注明修改，并以本声明的相同条款授权接收者。禁止闭源分发或对接收者附加与本声明冲突的限制。
- 本声明不改变第三方代码、依赖、图片、商标及其他材料原有的许可或权利；使用和分发这些内容时，仍须遵守其各自的条款。本声明仅适用于本项目权利人有权授权的内容。

由于本许可限制商业使用，它属于**源码可用许可**，不符合开放源代码促进会（OSI）的开源定义；请勿将其标为 OSI 认证的开源许可证。
