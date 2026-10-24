# LYNK 05 桌面研究与设计

针对领克 05 PHEV / IP753 / Android 9 的桌面项目，包含 APK 分析、设计和 Flutter Android 实现。包名 `xyz.i4o.uni.launcher`；源码、测试和报告由本地 Git 管理，先模拟器验证，再配合实车接入。

- **当前实现**：[Flutter 构建与架构](app/README.md)、[Android 9 验证报告](app/verification/emulator-report.json)。Flutter 绘制界面，复用 Java 原车适配器；毛玻璃可在设置开启，默认关闭。
- [Flutter 深色首页](app/verification/flutter-home-dark.png)、[浅色直角首页](app/verification/flutter-home-light-square.png)、[毛玻璃设置](app/verification/flutter-settings-blur-on.png)、[未连接状态](app/verification/flutter-live-unavailable.png)。
- [早期 WebView 基线与原生适配器](android/README.md)、[基线验证报告](android/verification/emulator-report.json)。保留供对照；当前 APK 入口已使用 Flutter。

- [APK 能力分析](docs/APK_ANALYSIS.md)：系统身份、Widget、ECARX 车辆接口、导航、媒体、界面结构与证据边界。
- [产品与界面设计](docs/PRODUCT_DESIGN.md)：布局、主题、组件、操作和异常状态。
- [接入与实施计划](docs/INTEGRATION_PLAN.md)：适配器、数据契约、分期任务、实车验证。
- [视觉方向说明](design/VISUAL_DIRECTION.md)：V04：原厂卡片覆盖、指定顺序底栏、长按首页设置、主题/圆角与自由卡片。
- [样式评审板](design/index.html)：含首页、设置和卡片编辑；点击“体验桌面”进入浏览器交互演示。
- [深浅色对照](design/home-pair.png)、[深色首页](design/home-dark.png)、[浅色首页](design/home-light.png)、[音乐底栏细节](design/dock-detail.png)。
- [桌面设置](design/settings-dark.png)、[编辑布局](design/card-edit-mode.png)、[卡片库](design/card-library.png)、[单卡设置](design/card-settings.png)。
- [0 圆角直角预览](design/home-square.png)。
- [原厂卡片总览：深色](design/oem-cards-dark.png)、[浅色](design/oem-cards-light.png)、[第二页](design/secondary-dark.png)。
- [官方提供组件映射](analysis/official-widgets.json)、[交互验证结果](analysis/design-verification.json)。
- [证据索引](analysis/evidence.json)、[APK 清单](analysis/inventory.json)。

## 查看设计

直接用浏览器打开 `design/index.html`，或在本目录运行：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory design
```

访问 `http://127.0.0.1:8765`。底栏顺序为：首页/全部、空调操作、音乐控制、音乐信息、车辆信息、360。长按首页按钮或首页空白进入设置，长按卡片进入编辑；可操作主题、圆角、卡片与各展开面板。卡片和空白页均保存于浏览器，兼容读取 V03 偏好。

`?view=secondary` 查看第二页，`?view=cards` 查看全部官方卡片样式；`settings`、`edit`、`library`、`climate`、`music`、`vehicle`、`camera` 可直接进入对应状态，`export=1` 禁用偏好读写便于导图。全部数据为示例或占位，未连接车辆。已覆盖 9 类 / 14 提供组件，官方完整字段尚缺 Provider APK 或实车证据，不能视为已实现同值接入。参考图仅作本地研究，出处保留于 `design/references.json`。

本地安装 Chrome 与 Node.js 后，在本目录运行 `node tools/render_design.mjs`，会用独立临时浏览器配置验证交互并导出全部设计图，结果写入 `analysis/design-verification.json`；不使用个人浏览器资料。

## 复现静态分析

依赖 Python 3、Androguard 4.1.4、lxml、loguru。本机已有依赖目录 `/tmp/linkco-apk-python`：

```sh
PYTHONPATH=/tmp/linkco-apk-python python3 tools/analyze_apks.py ../launcher/Launcher3_V2023-08-21_b5bd9b1.apk analysis/raw/official
PYTHONPATH=/tmp/linkco-apk-python python3 tools/analyze_apks.py '../launcher/嘟嘟桌面PRO-领克专享_领克专享1.015017.apk' analysis/raw/dudu
python3 tools/summarize_evidence.py
```

提取结果保留于本地 `analysis/raw/`，不提交原 APK、整包反汇编、第三方素材或签名私钥。Git 管理原创原型、规划文档、提取工具和精简证据。每项接口事实标明静态证据；上车可用性单独验证。
