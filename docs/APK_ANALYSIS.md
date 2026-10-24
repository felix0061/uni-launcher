# 两个 Launcher 的能力分析

分析日期：2026-10-24。输入为 `../launcher/` 中用户提供的 APK；未在本轮连接车机、运行这两个 APK 或抓取车辆总线和网络流量。此前 ADB 已验证的车机为 `dcy11` / Android 9 / `AP_IHU_CN_IP753_21082602`。本报告区分清单声明、代码调用、资源定义与实车验证。

## 1. 样本身份与适用性

| 项目 | 官方 Launcher3 样本 | 嘟嘟领克专享样本 |
| --- | --- | --- |
| 包名 | `ecarx.launcher3` | `com.dudu.autoui` |
| 版本 | `V2023-08-21_b5bd9b1` / 58 | `领克专享1.015017` / 1015017 |
| min / target SDK | 18 / 28 | 21 / 28 |
| 共享 UID 声明 | `android.uid.system` | `android.uid.system` |
| 签名证书 SHA-256 | 两者均为 `c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8` | 同左 |
| DEX 类数 | 2,844 | 15,931，两个 DEX |
| 原生库 | 日志等库，包含 arm64 / armv7 / x86 | arm64 的 DVR、灯光、腾讯定位库 |
| 清单组件 | 3 Activity、1 Service、2 Receiver、4 Provider | 12 Activity、9 Service、1 Receiver、3 Provider |

身份事实见 [inventory.json](../analysis/inventory.json)。声明系统 UID 和匹配签名提供了特权接入的线索，不等于设备授予全部权限，也不等于具备 root 身份。实际权限与 SELinux 约束需单独查询。

官方样本是 2023 年版本；用户固件版本号包含 2021 年日期。样本含 DCY11 车型配置，与此前实测产品名相符，但尚不能认定它就是车内当前 Launcher，或者里面每个组件在本车都存在。

## 2. 官方桌面的实际职责

官方主体是定制 AOSP Launcher3：`Workspace + CellLayout + Hotseat + AppWidgetHost`，提供分页网格、快捷方式、文件夹、拖拽、Widget 选择/缩放和应用面板。`res/layout/launcher.xml` 定义工作区、Dock、页码、编辑/Widget 面板；不是一个内置所有导航、音源和空调业务的大应用。

DCY11 的 `res/xml/dcy11_widgetpage_default.xml` 指定了以下部件，均为静态默认配置，需在本车枚举 Provider 后确认存在：

| 内容 | 提供者 | 默认位置 / 跨格 |
| --- | --- | --- |
| 媒体 | `ecarx.xsf.mediacenter/.widget.MediaWidgetProvider1x2` | 首页 x0，1×2 |
| 导航 | `ecarx.naviservice/.widget.BaseWidgetProvider` | 首页 x1，1×2 |
| 天气 | `com.ecarx.smartcloud/ecarx.home.module.widget.WeatherWidgetProvider1X1` | 首页 x2 y0，1×1 |
| 日历 | `ecarx.calendar/.widget.WidgetDynamicProvider` | 首页 x2 y1，1×1 |
| 账号 | `ecarx.membercenter/.app.appwidget.GidWidget` | 第二页 x0，1×2 |
| 清理 | `ecarx.autosecure/.widget.CleanWidgetProviderBesom1x3` | 第二页 x1，1×2；以 XML 跨格为准 |
| 胎压 | `com.ecarx.xcvehicle/.widget.TirePressureWidget1x2` | 第二页 x2，1×2 |

证据 O05。媒体更新还使用 `ecarx.launcher3.widget.MediaUpdate` 定向广播；常规更新为 `android.appwidget.action.APPWIDGET_UPDATE`，附 `appWidgetIds`。证据 O01。部件能展示和点击，不意味着宿主自动获得其内部歌曲、导航或车辆数据模型。

官方应用网格配置为 DCY11 `6x2` 变体，列出高德车机、腾讯车载音源、蓝牙电话、账号、天气、主题、商店、设置、`com.ecarx.hmi`、车辆信息、DVR 等应用入口。摄像头变体分别配置 AVM/PAC；不得把其中一个摄像头类硬套到所有车辆。

## 3. 官方与系统、车辆的交换

| 交换对象 | 发现的机制 | 能确认的范围 |
| --- | --- | --- |
| 车辆配置 | `com.ecarx.xui.adaptapi.car.Car.create` → `ICar` → `getICarFunction().getFunctionValue` | 查询摄像头配置；不是桌面直接绘制摄像画面 |
| 空气质量能力 | `getSensorManager().isSensorSupported` | 探测 PM2.5 支持后调整 Widget；不能据此推导温度控制能力 |
| 设备信息 | `Device.create`、车型/项目/供应商、DVR 配置方法 | 选车型、应用适配和配置；部分信息可识别设备 |
| 蓝牙电话 | `Bt.create` → HFP → `getHfpCallList` | 存在通话状态查询；没有看到完整电话栈由 Launcher 实现 |
| 系统主题 | `Configuration.uiMode`、配置变化、`THEME_APPLIED`、壁纸变化 | 系统昼夜切换、图标缓存和主题刷新，见 O03 |
| Widget 宿主 | AppWidgetHost、跨用户广播 | 绑定和承载其他应用部件；Widget 权限需实际检查 |
| 应用面板 | 导出的 `AppPane` / `AppPaneService`，action `ecarx.launcher3.ACTION_APP_PANE_SERVICE` | 官方面板可作为候选入口；绑定约束和 Binder 行为需实测 |
| 系统启动 | 首次加载与 `com.ecarx.intent.action.EAS_LAUNCH_BAT_0ST` 等广播 | 存在桌面生命周期协作，不能由新桌面无条件伪造 |
| 桌面数据 | `ecarx.launcher3.settings` 等 ContentProvider | 布局、快捷方式、Widget 记录；写权限有签名保护 |

证据 O01–O05。`CarUtils.updateCarConnected` 中读取的摄像头配置 ID 为 `587400448`，PM2.5 支持查询 ID 为 `1049344`。这些是样本中的车型常量，仅用来定位接口；新程序应通过车型适配器和枚举能力判断，不向任意车辆发送数字指令。

用户之前的照片中，原车底部空调栏在多个第三方页面仍然存在；这支持“它位于普通 Launcher 页面之外”的判断。**具体窗口进程归属尚未查询**，不能仅凭 Launcher APK 将整条底栏归到 `ecarx.launcher3` 或 `com.ecarx.hmi`。规划默认沿用原车常驻区，并以 `dumpsys window` 核实所有者与 Insets。

## 4. 嘟嘟的车辆接口：确有读写调用

嘟嘟的一个领克适配分支使用 `ServiceManager.getService("ecarxcar_service")`，转为 `IECarXCar`，再 `ECarXCar.createCar`。车辆能力来自设备框架/服务，而不是桌面自己实现 CAN 总线协议。证据 D01。

| 能力 | 状态读取 / 订阅 | 控制调用 | 结论 |
| --- | --- | --- | --- |
| 双区温度 | `getPA_CL_LeftTemp/RightTemp`、相应回调 | `CB_CL_LeftTemp/RightTemp` | 可作为本车适配候选；代码显示温度乘 2 写整数、回读除 2，量程须实测 |
| 风量 | `getPA_CL_FanLevel`、回调 | `CB_CL_FanLevel` | 档位与车机的可用范围尚未验证 |
| 空调开关 / AUTO / A/C | `getPA_CL_ClimateOn/Auto/AC` | 对应 `CB_CL_*` | 具有调用实现；接口返回不能替代状态回读 |
| 同步 / 内外循环 / ECO | `getPA_CL_Sync/Recirc/ECOClimate` | 对应 `CB_CL_*` | 可规划为次级操作 |
| 出风模式 / 前后除霜 | Mode、MaxDefrost、RearDefrost 等状态 | `CB_CL_Mode`、`CB_Mode_Defrst`、`CB_CL_MaxDefrost/RearDefrost` | 模式枚举、命令含义须逐个核对 |
| 座椅加热 / 通风 | SHC、SVC 状态与回调 | `CB_SHC_LeLvl/RiLvl`、`CB_SVC_Lvl` | 只能在车型装备和接口支持时出现 |
| 四轮胎压 | `ECarXCarVfmiscManager.getPA_dTPMS_TirePressure*` 与回调 | 未发现本分支需写操作 | 可规划只读卡片，单位与异常值先确认 |
| 亮暗相关状态 | `CarSignalManager.getTwliBriSts()` 和信号回调 | 本规划只订阅 | 作为自动主题候选；不能仅凭名称认定为“大灯开关” |

对应代码集中在 `com.dudu.autoui.manage.i.h.i.f`：`d` 为连接，`b` 为空调，`c` 为信号，`e` 为胎压。证据 D01–D05。

包内还有其他车型的 `CarPropertyManager.getProperty/setProperty/registerListener` 适配分支。这说明嘟嘟能适配多类车机；不能把这些分支的 property ID 直接套到 IP753。PHEV 电池 SOC、纯电续航、油量、总续航等在本次核实的领克分支中尚未形成明确映射，暂列后续探测项。

## 5. 导航：三种不同层级

1. **导航摘要**：嘟嘟监听 `AUTONAVI_STANDARD_BROADCAST_SEND`，读取 `KEY_TYPE`、`ICON`、`NEXT_ROAD_NAME`、`CUR_ROAD_NAME`、`SEG_REMAIN_DIS`、`ROUTE_REMAIN_DIS`、`ROUTE_REMAIN_TIME`、车道和路况 JSON 等；向 `..._RECV` 发控制消息。证据 D06。部分字段只在特定高德版本/渠道开放，应逐字段建可用性，广播未到达时不能显示旧导航为当前状态。
2. **完整应用嵌入**：`com.dudu.pipsdk.Pip28View` 直接使用 Android 9 隐藏 `android.app.ActivityView`；另有 `VirtualDisplay` 反射、DPI、触控显示 ID 与 release 逻辑。证据 D07。它不是普通应用随处可用的标准地图控件，需要固件、特权、目标应用和触摸/焦点共同验证。
3. **拓展透出**：`DevPluginPopupAMapService` 使用 `com.autonavi.plus.showmap/closemap`，带 x/y/w/h。证据 D08。这是另一路拓展协议，不能假定普通高德车机版响应，更不能与标准广播摘要混为一谈。

未发现嘟嘟内置 `TextureMapView` / `AMapNaviView` 类及常见高德地图引擎库；结合直接的 ActivityView 调用，可以确定该样本存在宿主嵌入路径，但不据此排除动态模块中的其他实现。原型中的地图是原创示意图，不代表地图 SDK 已接入。

## 6. 音乐、通知与其他信息

嘟嘟的 `GetMusicInfoService` 是通知监听服务，调用 `MediaSessionManager.getActiveSessions`、`MediaController.getPlaybackState` 和媒体回调；另有多个音源专用插件与音源服务权限，例如腾讯车载和酷狗。证据 D09 与清单。新桌面应优先采用标准媒体会话，在会话缺失时再接音源专用协议；歌曲和封面不能依靠读取屏幕文字作为主方案。

官方媒体 Widget 既有绘制也有交互，可作为兼容视图。其内部媒体中心如何控制每个音源，需要另取媒体中心 APK 或实车服务信息确认，本 Launcher 样本不足以完整说明。

嘟嘟还包含无障碍、通知、开机/屏幕状态、定位、Wi-Fi/蓝牙、应用使用情况、悬浮层、安装更新和状态栏服务。`LingkeStateBarPopupService` 是领克专用状态栏浮层，属于桌面扩展能力，不能推导它替代了所有原车系统 UI。证据 D10。

网络字符串涉及嘟嘟更新/内容域名、腾讯定位以及歌词/音乐服务。证据 D11 记录域名而不记录密钥；**字符串存在不证明实际发生通信，也未完成服务器行为或隐私流量审计**。官方样本包含统计 SDK、设备信息接口，但明文业务域名较少，服务也可能在外部框架。新桌面将天气、歌词、内容下载作为可关闭的独立来源，核心首页可离线工作。

## 7. 现有界面的设计取舍

| 样本 | 资源/代码可观察的结构 | 值得继承的点 | 新桌面的取舍 |
| --- | --- | --- | --- |
| 官方 | 多页工作区、固定网格、Dock、Widget 编辑/缩放、昼夜图标 | 部件兼容、原车入口、车型配置、系统生命周期协作 | 首页集中导航与音乐；完整应用网格移到抽屉 |
| 嘟嘟 | Dock、Prompt、MinimalismPaperView、可调分区、多个卡片/挂件；无界布局类；皮肤与深浅动画资源 | 统一音源适配、车控回调、可配置常用入口、应用嵌入 | 固定主布局，保留少量排序能力，配置移入设置 |

证据来自解码 XML、类名和方法；没有把反汇编出来的 XML 当作真实运行截图。嘟嘟资源名称被混淆，某些尺寸由运行时代码设置，静态 XML 的占位值不能当作最终排版尺寸。未评价两者实际启动速度、内存、触控延迟和可靠性，这些需要同机测量。

## 8. 对新桌面的决定

优先顺序为：原车系统常驻区兼容 → 应用启动与 Widget 基线 → 标准导航/媒体数据 → ECARX 空调与胎压 → 完整应用嵌入 → PHEV 能量信息。桌面自身数据使用独立仓库；每个接口有明确可用、只读、待确认、断开状态。

Android 官方文档说明，跨应用活动媒体会话需要媒体控制权限或已启用的通知监听；Widget 绑定也需要宿主授权流程。具体方式分别见 [MediaSessionManager](https://developer.android.com/reference/android/media/session/MediaSessionManager) 与 [Widget Host](https://developer.android.com/develop/ui/views/appwidgets/host)。这些是通用 Android 契约；ECARX 私有接口结论来自本地 APK 证据，尚无实车可用承诺。
