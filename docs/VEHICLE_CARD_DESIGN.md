# 车辆卡片设计与实现

新增 `battery` 动力电池卡；沿用 `air`、`vehicle` 类型，分别展示车内空气和行车信息。三张卡片默认 4 × 3，最小 3 × 2，可在卡片库添加、重命名、调整尺寸、保存。默认七张卡片及其位置不变，不自动插入新卡片。

## 信息与状态边界

| 卡片 | 主信息 | 次级信息 | 边界 |
| --- | --- | --- | --- |
| 动力电池 `battery` | `batteryPercent`，百分比与连续比例条 | 驾驶模式与能量流独立读取；外接充电显示“待同步” | 95% 精确填充轨道宽度的 95%；电量不能推出混动模式、充电状态或纯电续航 |
| 车内空气 `air` | `pm25`，单位 `µg/m³` | 独立的车内 `aqi` | 不判断优良差，不把车内 AQI 当室外 AQI，不互相推算 |
| 行车信息 `vehicle` | 车速、总里程 | 续航、距保养 | 分别读取 `speed`、`odometer`、`range`、`maintenanceMileage`；`range` 不标为纯电续航 |

电量、PM2.5、车内 AQI 已有原车字段接入。画廊中的 95%、PM2.5 12、AQI 28 等是固定**示例数据**，不代表当前车辆读数。驾驶模式、混动选择与能量流已按本车 SDK 的精确属性新增只读采集，见 [官方接口](OFFICIAL_CAR_API.md#05-phev-驾驶模式与能量流新增只读采集)，尚待实车同值验收。外接充电没有有效字段；纯电续航只保留未核实有效域的诊断原值。卡片不从电量或发电状态推断插枪。

`VehicleCardReading.fromNative(native, key, {nowMs})` 是只读展示适配，输入仍为现有 `vehicle.connected` 和 `vehicle.fields[key]`。展示组件不引入车辆指令；新增只读原生字段由 OfficialHybridReader 提供。

| 条件 | 主读数 | 提示 |
| --- | --- | --- |
| 已连接，字段有效，时间有效，单位确认 | 源数值，至多一位小数，整数不带 `.0` | 已同步 |
| 车辆未连接 | — | 未连接 |
| 单字段距更新时间超过 5000 ms | — | 等待更新 |
| 数值样本存在，但单位未确认或不受支持 | — | 单位待确认 |
| 缺字段、无效数值、错误时间戳等 | — | 暂无数据 |

沿用现有 `VehicleField` 的 5 秒有效期及最多 1000 ms 的未来时钟容差。每个字段独立失效；定时器在有效字段到期时刷新，即使原生事件暂时停止也不会一直保留旧读数。新有效快照可恢复显示，卸载卡片时取消定时器。

只接受有限、非负数值，电量还必须在 0–100。数值为零是有效读数。断连或无效电量显示“—”和空的中性轨道，不能看作 0%。不使用 `raw`、`sampleValue`、SDK 默认值或电池对象的 `level` 替代有效值。

电量单位固定 `%`，PM2.5 固定 `µg/m³`（兼容输入 `μ` 字形），AQI 为无量纲数值。行车字段必须各自满足 `unitVerified == true`：速度允许 `km/h`、`mph`、`m/s`，距离允许 `km`、`mi`。保留源数值和源单位，不转换、不把一个字段的单位用于另一个字段；未确认的行车单位不显示。

## 组件与兼容

- `app/lib/widgets/vehicle_cards.dart`：`BatteryCard`、`AirQualityCard`、`DrivingInfoCard` 接收 `native`、可选 `title` 和可选测试时钟 `nowMs`。组件只负责卡片内容；外层继续由现有 `EditableCard` / `GlassSurface` 提供表面、编辑工具与圆角。
- `BatteryLevelBar(value: double?)`：连续比例条；不按十格取整，不将无效值夹成 0 或 100。
- `app/lib/model/vehicle_card_data.dart`：`VehicleCardReading` 和 `VehicleReadingState`，统一读数、单位、显示文字与失效状态。
- `card_content.dart` 分发三张卡片，`card_layout.dart` 只新增 `battery` 类型；编辑器为三张卡片提供 3 × 2、4 × 3、8 × 6 尺寸选项，拖动仍可调整到其他合法网格尺寸。
- 原 `air`、`vehicle` 保存记录仍可读取。旧默认标题“空气质量”“车辆信息”“行驶信息”只在展示时替换为新名称，不重写保存记录；其他自定义名称保留。`vehicle` 不再显示重复胎压，`tpms` 保持独立。
- 复用 `SurfaceStyle`、`Design.px`、主题强调色、半透明/毛玻璃及 0–40 圆角；无左侧栏。小尺寸和编辑工具预留空间通过紧凑布局与缩放画布适配，放大文字时相应扩大内部画布。
- 原创电池符号位于 `design/index.html`，仅同步 `app/assets/icons/battery.svg`；未批量重写其他图标资产。

## 评审板与复现

`app/integration_test/vehicle_card_gallery.dart` 是独立画廊入口，使用真实卡片组件与 `GlassSurface`，不加载 Launcher、NativeGateway 或真实车辆，不保存布局。`VehicleCardGallery` 接收 `appearance`、`state` 及可选的本地评审字体 `fontFamily`；固定画布为 1600 × 900，导出为 1920 × 1080。每板同时展示 4 × 3 和最小 3 × 2，显著标注“示例数据”。

`VehicleGalleryState` 提供有效读数、断连、部分字段失效三种情形；还覆盖浅色直角和深色 40 圆角毛玻璃。固定数据仅存在于画廊和测试中，不用于桌面演示或实车回退。

独立设备集成入口及截图接收器：

```sh
cd app
python3 tools/flutter_task.py drive --no-pub \
  --driver=test_driver/vehicle_cards_driver.dart \
  --target=integration_test/vehicle_card_gallery_test.dart \
  -d <设备编号>
```

`integration_test/vehicle_cards_test.dart` 保留旧入口兼容。截图接收器只写入 `app/verification/vehicle-cards/` 的 PNG 与报告，不申请权限、不启动媒体、不改布局。设备运行仍由 Flutter drive 安装并启动测试应用，应与其他设备验证串行执行。

单文件组件/状态测试及可选桌面 PNG 导出：

```sh
cd app
python3 tools/flutter_task.py test --no-pub test/vehicle_cards_test.dart

# 需要本地中文字体；可用 VEHICLE_GALLERY_FONT 指定其他字体文件。
python3 tools/flutter_task.py test --no-pub test/vehicle_cards_test.dart \
  --dart-define=VEHICLE_GALLERY_OUTPUT=verification/vehicle-cards \
  --dart-define=VEHICLE_GALLERY_FONT=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
```

覆盖数值/单位/时效边界、精确电量填充、无新事件时到期、独立字段恢复、断连、最小/编辑空间、文字缩放、主题/毛玻璃/圆角，以及卡片库添加、编辑、持久化、重载和旧类型兼容；保存流程使用内存 FakeGateway，不发送车辆指令。

浏览器设计位于 `design/oem-cards.js`、`oem-cards.css`、`customize.js` 与 `index.html`。打开 `design/index.html?view=vehicle-cards&theme=dark&export=1` 即可单独评审；支持 `theme=light`、`state=disconnected|partial`、`radius=0..40`、`glass=0|1`、`palette=blue`。`export=1` 禁止写入浏览器保存的布局。

```sh
node tools/render_vehicle_cards.mjs
```

该独立工具使用临时浏览器配置，校验添加/编辑、95% 比例、断连、独立字段、圆角及内容边界，生成 `design/vehicle-cards-*.png`、更新 `design/oem-cards-{dark,light}.png` 并输出 `design/vehicle-cards-report.json`。原总览导出工具仅同步新增卡片后的总览高度。

## 最终验证

三张卡片已纳入整套 Flutter 组件回归；Android 9 独立画廊已导出包含驾驶模式 / 能量流及外接充电占位的八张图，位于 `app/verification/vehicle-cards/`。浏览器设计另有 53 项检查、10 张导图。评审图中的固定数值均为示例，未在本轮连接实车。构建与联合验证计数见 `app/verification/build-report.json`。
