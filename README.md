# LYNK 05 桌面研究与设计

针对领克 05 PHEV / IP753 / Android 9 的桌面方案，包含两个本地 APK 的静态分析、第三方设计参考和卡片式界面样式。按用户最新要求，本阶段先评审视觉风格，功能实现留到后续。

- [APK 能力分析](docs/APK_ANALYSIS.md)：系统身份、Widget、ECARX 车辆接口、导航、媒体、界面结构与证据边界。
- [产品与界面设计](docs/PRODUCT_DESIGN.md)：布局、主题、组件、操作和异常状态。
- [接入与实施计划](docs/INTEGRATION_PLAN.md)：适配器、数据契约、分期任务、实车验证。
- [视觉方向说明](design/VISUAL_DIRECTION.md)：设计参考、三个方向、推荐样式。
- [样式评审板](design/index.html)：切换三种配色方向，查看深浅色首页和空调样式；控件为视觉示意。
- [证据索引](analysis/evidence.json)、[APK 清单](analysis/inventory.json)。

## 查看设计

直接用浏览器打开 `design/index.html`，或在本目录运行：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory design
```

访问 `http://127.0.0.1:8765`。所有车辆、地图、媒体数据均为示例，不连接车辆、不加载地图服务。页面上的选择按钮只切换样式方案。底部常驻区为示意，真实归属与可用窗口须实车核对。参考图保留于本地忽略目录 `design/reference-images/`，作者和公开来源记录在 `design/references.json`；原创样式源文件及导出 PNG 纳入 Git。

## 复现静态分析

依赖 Python 3、Androguard 4.1.4、lxml、loguru。本机已有依赖目录 `/tmp/linkco-apk-python`：

```sh
PYTHONPATH=/tmp/linkco-apk-python python3 tools/analyze_apks.py ../launcher/Launcher3_V2023-08-21_b5bd9b1.apk analysis/raw/official
PYTHONPATH=/tmp/linkco-apk-python python3 tools/analyze_apks.py '../launcher/嘟嘟桌面PRO-领克专享_领克专享1.015017.apk' analysis/raw/dudu
python3 tools/summarize_evidence.py
```

提取结果保留于本地 `analysis/raw/`，不提交原 APK、整包反汇编、第三方素材或签名私钥。Git 管理原创原型、规划文档、提取工具和精简证据。每项接口事实标明静态证据；上车可用性单独验证。
