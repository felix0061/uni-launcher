# 多方向红绿灯接入范围

核对日期：2026-10-27。区分地图 App 内部显示、对外本地广播和开放平台服务。多流向（左、直、右等）也不等于给每条物理车道都提供独立灯态。

| 来源 | 已核对的数据能力 | UNI 桌面的接入状态 |
| --- | --- | --- |
| 用户提供的高德官方车机 9.5.0.600013 | 标准 KEY_TYPE=60073 的 IntentBuilder 只写入一组 dir/status/countdown，没有多方向数组 | 保留单项接入；不能由这组广播还原全部方向 |
| 用户提供的同版本 yh 修改版 | 额外广播含 lights 数组，每项 direction/status/countdown；从自身 UI 资源数组核对到部分枚举 | 0.6.15 增加已确认方向/灯色；支持批量展示；此前真实样本只有一项 |
| 用户提供的百度车机 22.0.1 | 内部多方向模型与 `TRAFFIC_LIGHT_UPDATE` 通知；未建立该通知到 Android 广播的调用链 | 未新增接收器，不能把内部事件名称直接当成广播 action |
| 用户提供的腾讯车机 9.11.0.159 | 内部多方向倒计时经 SDK Binder 回调；标准广播中确认的相关字段是路线剩余灯数量 | 未新增广播适配；另有可进一步验证的 Binder 订阅入口 |
| 百度地图开放平台 | 官方红绿灯动态查询返回方向、灯态、倒计时和置信周期；超视距巡航明确以数组提供同路口多个方向 | 可作为未来独立数据源；尚未申请/验证接口权限，没有接入安装版百度 App 的本地广播 |
| 腾讯位置服务 | 官方产品公告明确前向查询支持直、左、右、掉头等流向独立计时，含前方路口及历史轨迹吸附能力 | 可作为未来独立数据源；尚未取得接口权限/Key、核实完整契约，没有接入安装版腾讯 App 的本地广播 |

高德结论严格限于这两个本地 APK 的对外实现，不推断所有新版高德或商业 SDK 都有同一限制。高德导航 SDK 的红绿灯显示能力，也不能证明另一个进程可以读取已安装高德 App 的多方向数据。

百度动态接口需要进入路口的道路 linkid 和服务端类型 AK；每个信号灯的多组周期字段是先后相位，不能错当成多个方向。接入时还要处理时间戳、置信期、10000（未挖掘到倒计时）等缺失值。

百度/腾讯的云服务接入需要独立申请权限、核实配额与授权；不能靠安装对应 App 自动获得服务，也不能在没有 Key/接口实测时标记“已支持”。现有 UNI 卡片和限时状态模型可复用，但每个来源的枚举、坐标、路口/方向匹配及有效期必须独立适配。

官方资料：

- [百度红绿灯动态查询](https://lbsyun.baidu.com/docs/webapi?title=lamp_service/countlight/route)：多流向、灯态、周期、服务端 AK。
- [百度超视距巡航](https://lbsyun.baidu.com/docs/webapi?title=bvr/cruisebrv/api)：同路口多方向数组、位置、路口及时间校验。
- [腾讯位置服务官方 2026 年产品公告](https://developer.cloud.tencent.com/article/2652383)：前向红绿灯、多流向独立计时。
- [腾讯 WebService 概述](https://lbs.qq.com/service/webService/webServiceGuide/webServiceOverview)：独立开放平台 API 的调用方式。
- [高德 SDK 红绿灯图面控制](https://lbs.amap.com/api/android-navi-sdk/guide/custom-ui/custom-other-overlay)：SDK 显示开关，不能当成车机 App 多方向广播协议。

## 本地百度、腾讯 APK 的实际出口

这部分只依据用户提供的安装包，不把开放平台能力套用到已安装 App。证据索引：[navigation-provider-evidence.json](../analysis/navigation-provider-evidence.json)。

**百度 `com.baidu.naviauto` / 22.0.1**

- 找到 `BMATrafficLightInfo`、`BDDirectionLightInfo` 等内部模型，以及 `Ls5/c.H → Lt5/b.d → Ls5/c.C/z → Lu5/a.a` 的 `TRAFFIC_LIGHT_UPDATE` 通知链。末端是进程内监听器调用，不是 `sendBroadcast`。
- 该序列化器写入 `lng/lat/detail`，其中有 `color/countdownTime/direction/mainFlow` 等字段。但 `detail` 是循环反复写入的单个 `JSONObject`，并非多方向数组；不能根据字段名假设它会对外提供全部方向。
- 包内还存在 `com.baidu.BaiduMap.OPENAPI_CALLBACK` 广播，发送要求接收方持有 `com.baidu.BaiduMap.permission.OPENAPI_RECEIVE`，并有功能开关与鉴权；失败时返回 code=113。没有找到上述交通灯事件连到这个广播发送器的证据。这个 APK 未声明该权限的保护等级，不能声称它必定是签名权限。
- 结论：有内部数据，尚未确认可供 UNI 直接接收的红绿灯广播。不注册猜测的 action，也不把合成数据作为百度接入成功。

**腾讯 `com.tencent.wecarnavi` / 9.11.0.159**

- `MultiLightCountdownTimerInfo → Lab/b.j → SdkAutoStatus.MAP_NAVI_TRAFFIC_LIGHT_INFO → NaviSdkApiImpl.l1` 最终调用 `RemoteCallbackList<ICommonStateListener>.onAutoStatusChangedDetail(int,String)`。这是 Binder 回调，`RemoteCallbackList.beginBroadcast()` 也不是 Android Intent 广播。
- 确认存在 `WECARNAVIAUTO_STANDARD_BROADCAST_SEND`，受 `isSendStatusBroadcast()` 配置约束。其路线广播 KEY_TYPE=2004 的 `rg_on_remain_traffic_light` 来自 `GuideInfoModel.remainLightCount`，含义是剩余灯数量，不能拿来显示倒计时、箭头或灯色。没有在已追踪发送路径中确认多方向灯态载荷。
- `NaviSdkService` 在清单中 exported=true、没有声明服务权限，并提供 `registerCommonStateListener` / `unregisterCommonStateListener`。这是后续可验证的另一条 IPC 路线；尚需核对调用方校验、事件枚举与 JSON、订阅/释放生命周期以及真实路口回调，当前未启用。
- 结论：未找到可直接增加的多方向红绿灯广播适配；保留 Binder 候选入口，不把内部 SDK 模型标成已接入。

可用 `tools/analyze_navigation_signals.py <APK> --out analysis/raw/<来源>-signals --references '<类/方法正则>'` 重新生成证据。整包字节码和字符串只保留在忽略入库的 `analysis/raw/`，Git 保留工具、输入哈希与人工核对结论。

高德本地 APK 证据：`analysis/amap-traffic-evidence.json`；合成广播验证：`app/verification/car-fixes-0.6.15/traffic-lights/native-report.json`。
