# 0.5 官方 Launcher3 迁移审计、实现与上车验证

审计日期：2026-10-25。此文记录当前工作区及本轮独立入口补齐，不替代发布验收。**尚未完整移植官方 Launcher3；9 类 / 14 个 Provider 的目录覆盖不等于实时字段或动作已全部迁移。** 本轮只连接 Android 9 模拟器，没有连接车机、安装实车 APK 或发送车控命令。源码和最终验证报告使用本地 Git 管理。

## 证据与判定边界

| 证据 | 可确认内容 | 不可据此确认 |
| --- | --- | --- |
| `analysis/raw/official/inventory.json`、`AndroidManifest.xml` | 官方 `ecarx.launcher3` V2023-08-21_b5bd9b1 / 58，系统 UID、权限、组件；APK SHA256 `203b478878d96af54bdb998770cb4e4e245d960fe069f94d839565c433a9aa6d` | 当前新 APK 自动获得原厂权限；全部业务由 Launcher 自己实现 |
| `analysis/raw/official/xml/res/xml/dcy11_widgetpage_default.xml` | DCY11 默认七类 Widget 的精确包 / 类 / 位置 / 跨格 | 外部 Provider 的完整业务字段、数值单位、账号上下文与点击行为 |
| 其他 `*widgetpage*` XML、`LauncherModel.<init>/hideHVACWidget` | 共九类、十四个组件；AQI 随 PM2.5 能力过滤；出行服务属于其他车型配置 | 所有变体均在本车安装，或出行服务属于领克 05 默认能力 |
| `analysis/official-widgets.json` | 目录唯一来源；`contentSchemaVerified=false`；`sameSourcePolicy` 要求来源 / 版本 / 字段 / 单位 / 精度 / 空态 / 时间戳 / 上下文 / 动作分别验收 | 改成已验证，或凭 RemoteViews 出现认定统一卡片字段已接通 |
| `analysis/raw/official/bytecode.txt` 的 `Utilities`（约 71630 行）与 `dcy11_ecarx_workspace_6x2*.xml` | 设置、天气有不同配置使用的包名，必须区分车型资源与通用常量 | 用类名前缀猜安装包，或仅凭一个常量把已有车型入口改错 |
| 同文件 `AppWidgetManagerCompatVL.startConfigActivity`（约 131937 行） | 官方宿主会在绑定后调用 `AppWidgetHost.startAppWidgetConfigureActivityForResult` | 不配置就保存一个“完成”的绑定 |
| [0.4 对照](OEM_PARITY_0_4.md)、[官方车辆合约](OFFICIAL_CAR_API.md)、[车辆卡片说明](VEHICLE_CARD_DESIGN.md) 与当前源码 | 后续已补充的车辆接口、展示与已报告实车读数 | 沿用 0.4 的“所有 SOC/PM2.5 都无接口”结论；也不能把历史取证写成本轮实车测试 |

本地后续取证已有 SDK、媒体主 APK、网易云主 APK，以及文档记录的实际 XCHvac 实现。`com.ecarx.hvac.inter.apk`、`com.ecarx.xcvehicle.inter.apk` 是资源覆盖包，不是包含业务 DEX 的主 APK；已有车辆合约记录现车无 `com.ecarx.xcvehicle` 主包。本轮所读输入未包含账号、日历、清理、天气各 Provider 的主 APK / 完整字段契约。缺包、缺业务协议和缺实车同值验收是不同阻塞。

## 本轮已实现

### 精确目录与真实应用入口

- `OfficialCatalog` 继续直接读取打包的 `official-widgets.json`，保留全部九类 / 十四组件；对 `music→media`、`nav→navigation` 归一化，对 null / 未知类型关闭匹配。
- 新增 `OfficialEntryAdapter`，只接受**包名和完整类名同时相同**的 Provider。相同类名但包不符、相同包但类不符均拒绝；按目录顺序优先 DCY11，已经保存且仍在目录中的变体可以继续用。此判断不是厂商证书或版本认证。
- 原车应用通过 PackageManager 查真实启动 Activity，检查应用 / Activity 启用、exported、调用权限和解析后的精确包；检查后固定组件。查询异常、无 launcher、权限变化、安装变化均返回不可用。应用列表及已缓存应用启动也检查可访问性，不启用禁用组件。
- `packageFor()` 在证据候选中选择实际可启动者；原有 Runtime 调用可直接受益，无需修改 Runtime。Widget 不在时仍可单独打开原车应用；无安装或无权限时显示具体空态、禁用启动按钮，保留返回及重试。

| 类型 | Widget 包（完整类见唯一目录） | 原车应用候选顺序及出处 |
| --- | --- | --- |
| 账号 | `ecarx.membercenter` | 同包；DCY11 Widget / workspace |
| 清理 | `ecarx.autosecure` | 同包；DCY11 Widget / workspace |
| 日历 | `ecarx.calendar` | 同包；DCY11 Widget / workspace |
| 天气 | **`com.ecarx.smartcloud`**，类名却以 `ecarx.home` 开头 | DCY11 `com.ecarx.smartcloud` 优先，Utilities 的 `ecarx.weather` 次选；不能把 `ecarx.home` 当包名 |
| 设置 | 无此类 Widget | DCY11 workspace 的 **`com.ecarx.settings`** 优先，Utilities 的 **`ecarx.settings`** 次选；两者都有静态证据 |
| 导航 | `ecarx.naviservice` | 已有高德 `com.autonavi.amapauto`，再尝试目录中的 `ecarx.naviservice`；用户选择导航仍归现有导航模块负责 |
| 媒体 / 胎压 / AQI / 出行 | 各自目录中的精确包 | 对应包的可访问 launcher；不虚构深链或后台命令 |

### Widget 宿主闭环

`OfficialWidgetActivity` 保留独立 host `75301`，仅操作当前应用此 host 所有的 ID，补齐：

1. 枚举精确 Provider；没有组件则展示空态，并独立检查应用入口。
2. 自动绑定不被允许时请求系统授权；拒绝、取消、系统缺处理器时释放本次分配。
3. 有 `configure` 时调用官方同路径的配置 API；只有配置成功才保存完成绑定。配置取消 / 异常释放已绑定但未完成的 ID。
4. 授权回调以自身 ID、host 所有权、预期 Provider 和当前已安装组件复核，不信任返回 Intent 提供的任意 ID。
5. 已完成绑定重开复用；丢失或组件不符时重建。待授权 / 配置的 saved state 保留对应 ID / 组件 / 阶段；未完成分配有本应用 pending 记录，进程死亡后的下次进入可回收。旧 `music/nav` 偏好键向规范类型迁移。
6. 外来 host 的偏好 ID 不复用、不删除；不改原厂 Launcher 数据库或原厂 Widget host。
7. 用 HostView 实际测量宽高换算 dp 通知 Provider，移除硬编码 `600×320..1200×700`。可见时监听，停止时退订，服务异常有回退。

宿主明确提示“原车卡片独立显示，桌面摘要尚未同步”。RemoteViews 的登录、清理等实际动作仍由原应用实现；本轮没有构造账号 token、清理广播、天气 URI、日程查询或车控协议。

Android 契约参见 [Widget host 绑定与配置](https://developer.android.com/develop/ui/views/appwidgets/host)、[AppWidgetHost 配置与生命周期](https://developer.android.com/reference/android/appwidget/AppWidgetHost)、[AppWidgetHostView 尺寸](https://developer.android.com/reference/android/appwidget/AppWidgetHostView)。

### Flutter 可达入口

新建独立 `OfficialCardEntry`，在天气和日历卡片提供显式“打开原车天气 / 日历”；编辑预览不启动外部界面。账号和清理保留已有按钮，同样进入增强后的宿主，因此四类均可在卡片界面到达 Widget / 应用兼容路径。仅在 `card_content.dart` 增加导入和这两处分发，保留他人已完成的 battery / air / vehicle 分发。

## 官方功能完整范围与剩余缺口

下表中的“已有”表示源码具备该路径，不把历史或其他协作者验证算成本轮新验收。

| 官方能力 | 现有实现 / 本轮变化 | 尚缺 / 阻塞事实 | 上车核对 |
| --- | --- | --- | --- |
| HOME、横屏、开机与前后台 | 现有桌面路径；Runtime / GlobalDock 由主协作者负责 | 本轮未修改、未验收其集成；不等同官方所有启动协作广播 | 默认 HOME、开机、休眠唤醒、应用返回、后台常驻 |
| 应用面板、图标、启动、安装变化 | 已有抽屉与监听；本轮补可访问性与精确包检查 | 非原厂 AppPane Binder 服务的协议复制；多用户尚未实现 | 安装 / 卸载 / 停用、签名保护 Activity、图标更新 |
| 工作区分页、拖放、大小、编辑与保存 | 已有独立 Flutter 卡片仓库和主题 | 未迁移原厂数据库；不是 AOSP Workspace 的逐方法复刻 | 旧布局重载、边界拖放、性能、屏幕保护区 |
| 官方 Widget 九类 / 十四组件 | 单一目录 + 本轮绑定 / 配置 / 取消 / 回收 / 应用 fallback | 只做目录内独立全屏兼容宿主；任意第三方 Widget 选择器、嵌入每张统一卡片、原厂全部缩放限制未实现 | 每个实装 Provider 的尺寸、更新、触摸、配置、退出和休眠恢复 |
| 账号 | 兼容入口及准确缺失状态已实现 | 登录状态、头像、昵称、权益、车辆关联等字段与动作契约未核对；没有完整主 APK | 未登录 / 已登录 / 登出、隐私状态、返回，不采集凭据 |
| 清理 | 兼容入口已实现；统一卡片仍显示未知 | 空间 / 内存 / 垃圾量、清理范围 / 进度 / 结果未知，未发送清理动作 | 打开真实应用、取消、完成回读；区分内存与存储单位 |
| 日历 | 显式兼容入口已补；统一日期 / 日程仍未接原厂源 | 农历、节日、事件、账号日历及点击上下文未知；未把设备日期冒充原车日程 | 跨日 / 时区、无事件、事件点击、同步与退出 |
| 天气 | 显式兼容入口已补；已有 38 类图标和来源未知时回退 | 城市、定位、温度、高低温、天气码来源、预报、观测时间未接 Provider；天气 APK 不在本轮输入 | 断网 / 过期、定位、昼夜与官方码映射；不得默认晴天 |
| 媒体 | 已有定向关联应用、MediaSession 与网易云 adapter；可承载原厂 Widget | 不代表蓝牙 / USB / 电台 / QQ 等每种源、歌词、曲目上下文全迁移；本轮不复核后续媒体 APK 全契约 | 真源切换、无会话、音频焦点、歌词与曲目关联、按钮 actions |
| 导航 | 已有 Android 9 ActivityView / 实装应用选择和失败回退 | 平台权限、目标可嵌入、真实地图触摸 / 焦点 / 音频仍需实车；Widget 不是统一导航字段 API | 全屏返回、倒车打断、休眠、地图定位和触摸 |
| 空调 / 座椅 | 当前源码已有官方 SDK / PA 读取、类型 / 枚举 / 权限检查和显式 UI 命令 / 回读路径 | 0.4“所有真实控制禁用”已不是当前源码结论；仍不能认定每项车控已验收。本轮没有发送任何命令 | 依 [车辆合约](OFFICIAL_CAR_API.md) 逐项核对支持能力、ACK 与 PA 回读，失败不重放 |
| 胎压 | 当前官方 Reader 已读四轮 PA；历史文档报告 `220/215/215/215` 原始值；本轮可提供精确 Widget 兼容 | `unit=raw`，单位设置的默认回退不证明物理压力单位；不能标成已确认 kPa / bar / psi；XCVehicle 主包缺失与覆盖包不能混淆 | 四轮同刻原厂对照、无效编码、单位及冷热胎变化 |
| 车内空气 | 已有独立卡片；`OfficialVehicleSensors` 接 `pm25` / `aqi`，Reader 工作线程已调用 | helper 有契约证据和有效性检查，不代表本轮实车同值通过；不推导室外 AQI 或优良差 | 能力、PA ACTIVE、SDK 值、µg/m³、断连与过期 |
| PHEV 电量 | 已有独立卡片与 `batteryPercent` helper（BLI Double `data`，0..100，%） | 不能再写“完全无接口”；是否本车可用需回读。`level` 不是百分比；驾驶模式 / 混动选择 / 能量流已新增精确属性只读采集（尚未上车）；外接充电仍缺实现，专用电池续航只留诊断原值 | 对比 SOC，确认无值 / 零 / 百分比边界；逐项核对驾驶模式、混动选择与能量流；单独记录外接充电等缺项 |
| 行车信息 | 已有 speed / odometer / range / maintenanceMileage helper 与展示 | 默认速度 / 距离单位待确认，`valid=false`；不能凭数值量级贴 km/h / km，range 不称纯电续航；无已证实的燃油百分比 | 保留 raw / sampleValue 同刻对照，记录单位证据后再开放显示 |
| 360 / DVR / 摄像头变体 | 现有精确 AVM 组件启动；本轮复用可访问性检查 | 不启用组件，不把 PAC 替代 AVM；DVR / 倒车接管 / 焦点未经本轮验证 | 原厂窗口接管、倒车优先级、返回，桌面不覆盖安全画面 |
| 蓝牙电话、系统信号 / 网络状态 | 有原车应用入口，官方代码存在 HFP 等探测 | 新 UI 的全部系统图标 / 通话状态尚非完整 HFP、USB、网络订阅实现 | 通话焦点、信号来源、断连、弹窗、底部窗口归属 |
| 主题 / 壁纸 / 昼夜 | 已有跟随系统 / 自定义主题 / 圆角 / 毛玻璃 | 原厂主题包资源、壁纸选择及全部主题广播协作未完整迁移 | 系统昼夜、配置变化、图标资源和低内存表现 |
| 文件夹、手机式快捷方式、深链固定 | 官方有 FolderInfo、InstallShortcutReceiver 等实现；新桌面有快捷应用卡片 | 原厂文件夹层级、动态 / 固定快捷方式接收与恢复未实现；快捷应用卡不能代替这项结论 | 属于尚未实现的手机式 Launcher 特性，不能计作完成 |
| 多用户 / 工作资料、Widget ID 备份恢复 | 官方有跨用户处理、AppWidgetsRestoredReceiver | 当前宿主仅当前用户；没有原厂跨用户广播和恢复旧 ID 映射，不宣称恢复官方桌面数据 | 用户 / profile 适用性、备份恢复策略 |
| 官方 Launcher 专用系统协作 | Manifest、AppPaneService、首次加载等有证据 | 未复制签名 Provider 数据库 / Binder 协议 / EAS 私有广播；普通 UID 不等于 system UID | 只读确认固件依赖，不伪造启动或车辆事件 |

## 本轮验证与复现

| 验证 | 结果 | 实际边界 |
| --- | --- | --- |
| `python3 tools/test_official_entries.py --emulator emulator-5580` | Android API 28 javac、D8、aapt2、签名打包通过；授权阶段 49 项、拒绝阶段 33 项断言通过，共 82 项 | 临时隔离测试宿主 `xyz.i4o.uni.fixture.officialentry`；临时 `ecarx.calendar` 合成 Provider；不是原厂 APK；完成后卸载两者 |
| 原生精确匹配与启动测试 | null / 未知类型、两种别名、十四组件保留、错包 / 错类拒绝、目录顺序、已保存变体、两种设置 / 天气包候选、实际可用变体选择、包缺失 / 禁用 / 无入口 / 非导出 / 无权限 / 解析到别包 / 查询及启动异常 | Android 实际 JSON / ComponentName；PackageManager 边界部分使用 MockPackageManager，不声称厂商签名验证 |
| 原生宿主测试 | 实际 AppWidget binder 绑定 + configure 成功、配置取消回收、完成 ID 重开复用、实际 dp 尺寸、拒绝授权回收、应用 fallback、其他 host ID 不误删、未完成分配记录恢复、旧 nav 偏好键迁移 | 系统 bind 拒绝使用 ActivityMonitor 返回取消；源配置使用合成 Activity；没有点击原厂登录 / 清理 |
| `cd app && python3 tools/flutter_task.py test --no-pub test/official_card_entry_test.dart` | 四项通过 | 天气 / 日历 / 账号 / 清理均触发精确类型的 `official-widget`；缺数据仍显示未同步；小尺寸无布局异常；内存 FakeGateway |
| 上述入口测试与 `test/launcher_widget_test.dart` 联合运行 | 11 项全部通过 | 增加原有主界面、设置、卡片添加保存、真实模式无示例值、主题圆角、全部卡片最小编辑尺寸回归；不执行真实车辆动作 |
| `cd app && python3 tools/flutter_task.py analyze lib/widgets/official_card_entry.dart lib/widgets/card_content.dart test/official_card_entry_test.dart` | 无问题 | 仅本轮 Flutter 文件的定向分析 |
| `git diff --check` | 通过 | 不代表全工作区构建或实车验收 |

测试工具默认仅编译和打包，不访问设备；只有显式 `--emulator emulator-NNNN` 才执行安装。会同时检查序列号和 `ro.kernel.qemu=1`，任何既有同包均拒绝覆盖，测试 APK 标记 `testOnly`，不用生产 Launcher 的包、偏好或 host。完整 Flutter 发布构建与主协作者的 GlobalDock / Runtime 集成由主协作者统一执行，避免覆盖共享模拟器上的生产测试版本。

## 白天上车待办（尚未完成）

1. 先运行已有只读采集，记录实际安装包版本 / 启用状态 / 可访问 launcher、精确 Provider 列表、Widget 绑定权限及各窗口 owner / Insets；分清资源覆盖包与业务主包。没有对应包时应得到可返回空态。
2. 依次从账号、清理、日历、天气卡片进入。验证系统授权的允许 / 拒绝 / 再试，Provider configure 的成功 / 取消，应用 fallback、原厂 PendingIntent 点击、返回、再次进入及安装变化。记录每个“可显示”的真实组件与版本，**不要填写“统一字段接通”**。
3. 测试 Provider 重启 / 卸载、宿主被杀、配置中重建、休眠恢复和实际窗口尺寸，确认不重复分配、不误删原厂 host；saved-state 分支和配置时 Activity 重建仍需额外设备验收。
4. 在原厂界面与新卡片同一时间逐字段对照。账号 / 天气 / 日程 / 清理缺主包或接口时先取只读证据，不猜 ContentProvider URI、extra、广播、清理权限或数据单位。为每项填写来源、单位、精度、空态、时间戳及动作结果。
5. 按现有车辆合约只读核对 SOC、PM2.5、车内 AQI、胎压及速度 / 里程 / 续航 / 保养单位；单独记录充电、混动状态、纯电续航、燃油百分比仍未接通。单位未确认则继续空态。
6. 主协作者统一验收 GlobalDock、系统底栏保护、导航 / 媒体 / 通话焦点和倒车接管。只有显式用户动作与已核对合约才能测试真实控制；Widget 显示本身不证明任意控制可用。

本轮修改限定为 OfficialCatalog / OfficialWidgetActivity / AppRepository、新增精确选择 adapter、独立 Flutter 入口及其最小分发、独立测试与本文；没有修改 Runtime / MainActivity / Settings / Controller / BottomDock / 车辆卡片组件，也没有覆盖其他协作者的工作。
