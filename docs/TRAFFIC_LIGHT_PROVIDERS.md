# 多方向红绿灯接入范围

核对日期：2026-10-27。区分地图 App 内部显示、对外本地广播和开放平台服务。多流向（左、直、右等）也不等于给每条物理车道都提供独立灯态。

| 来源 | 已核对的数据能力 | UNI 桌面的接入状态 |
| --- | --- | --- |
| 用户提供的高德官方车机 9.5.0.600013 | 标准 KEY_TYPE=60073 的 IntentBuilder 只写入一组 dir/status/countdown，没有多方向数组 | 保留单项接入；不能由这组广播还原全部方向 |
| 用户提供的同版本 yh 修改版 | 额外广播含 lights 数组，每项 direction/status/countdown；从自身 UI 资源数组核对到部分枚举 | 0.6.15 增加已确认方向/灯色；支持批量展示；此前真实样本只有一项 |
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

本地 APK 证据：`analysis/amap-traffic-evidence.json`；合成广播验证：`app/verification/car-fixes-0.6.15/traffic-lights/native-report.json`。
