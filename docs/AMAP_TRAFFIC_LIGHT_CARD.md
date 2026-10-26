# 高德红绿灯数据与 UNI 卡片设计

2026-10-26。两份本地 APK 静态分析和卡片设计已完成；0.6.9 已实现卡片与广播接入，完成 Android 9 模拟器验证。真实高德路口广播、方向和灯态枚举仍待实车核对。

## 结论

具备接入路径。官方版含标准红绿灯广播构造与发送链，修改版保留该链，同时增加了巡航多方向广播。参考图中的左转、直行并排布局可以设计，但只有收到同一批次的多方向数据时才展示。不能根据多个时刻收到的官方单方向数据，拼出看似同时有效的多个信号。

静态代码证明接口存在，不证明当前账号、地区、渠道配置和具体路口一定触发发送。仍需在有红绿灯信息的路口记录广播，核对方向、灯态枚举、数据更新周期与退出条件。

## 输入 APK

| 文件 | 包名 | 版本 |
| --- | --- | --- |
| `Auto_9.5.0.600013_release_signed.apk` | `com.autonavi.amapauto` | 9.5.0.600013 / 26000001 |
| `9.5高德-完美自动投屏3D彩虹.apk` | `com.autonavi.amapautp.yh` | 9.5.0.600013 / 26000001 |

SHA-256 与精简证据见 [amap-traffic-evidence.json](../analysis/amap-traffic-evidence.json)。不同包名需要适配桌面的导航应用关联；不能写死官方包名。

## 官方标准协议

发送 action：`AUTONAVI_STANDARD_BROADCAST_SEND`，`KEY_TYPE=60073`。

| Extra | 类型 | 静态代码确认的内容 |
| --- | --- | --- |
| `dir` | int | 单个方向的原始值；语义映射待实测 |
| `trafficLightStatus` | int | 原始灯态；枚举待实测 |
| `redLightCountDownSeconds` | int | 模型定义的红灯倒计时秒数 |
| `waitRound` | int | 模型定义的等待轮次；显示规则待实测 |
| `greenLightLastSecond` | int，可选 | 受 `ib.t()` 条件控制，不保证每次携带；不能直接把它当成总是有效的绿灯倒计时 |

路径：`v70.a(JsonHeader,String)` 将 JSON 解析成 `RspTrafficLightsCountdownInfoModel` → `wh0.c()` 写入以上 extras → 广播发送分支 `fd.m(Intent)` 设置 action → `se.sendBroadcast(Intent)`。

本版本 `wh0.c()` 不写 `lightsData` 数组；不能套用其他版本或网络示例中同名协议的扩展字段。`TRAFFIC_LIGHT_NUM` / `trafficLightNum` 是路口灯数量类信息，不是实时灯态和秒数。

以上是本地 APK 证据。高德公开 [AutoSDK 灯态图层文档](https://a.amap.com/amapauto/static/bl/500/android/api/classcom_1_1autonavi_1_1gbl_1_1layer_1_1_guide_traffic_light_layer_item.html) 也定义了灯态和倒计时，但 SDK 图层 API 与已安装应用的对外广播是两套接口，不能用 SDK 文档替代本次 APK 的协议核对。

## 修改版巡航协议

新增类 `floatapp.CruiseTrafficLightBroadcaster`。

- `AutoamapPluginManage` 初始化它的 application context。
- `CameraLightInteract.notifyCameraLightInfosImpl(CameraLightInfoWrapper)` 在原始通知后调用 `onCameraLightInfo`。
- action 为 `NAVITOOL_CRUISE_TRAFFIC_LIGHTS`，extra `data` 是 JSON 字符串。
- JSON 顶层：`ts`（发送端当前毫秒时间）、`lights`（数组）。
- 每个数组元素：`direction`、`status`、`countdown`、`waitNum`、`showType`，均来自 `CameraLightInfo` 的字段。
- 发送函数直接调用 `Context.sendBroadcast(intent)`；这个函数没有指定接收包名或 permission。

因此该修改版确实具备把多个方向发送给其他应用的代码路径，更适合参考图。类名中的“Cruise”不等于已经证明未导航时所有路口都会发数据；仍以实测触发为准。

## 视觉方案

设计文件：[可浏览设计](../design/traffic-lights.html)、[1920×1080 深浅色设计图](../design/traffic-lights.png)。全部数据明确标为示例。

- 沿用 UNI 的表面色、主题色、文字色和可调圆角；毛玻璃遵循桌面设置，沿用非实时背景处理。
- 标题为“红绿灯”，右侧轻量展示关联地图名称，点击标题打开关联地图。
- 方向用线条箭头和淡色圆形底；倒计时用大号等宽数字，单位弱化。不使用无法从数据得到的整周期进度环。
- 灯色保留红 / 黄 / 绿语义，不随用户主题色改变；同时显示“红灯 / 黄灯 / 绿灯”文字，避免只依靠颜色。
- 单方向：紧凑横向布局，标题在左、方向和秒数在右。建议卡片尺寸 4×2。
- 多方向：两方向并排，大尺寸可扩为三方向；同批次数组决定显示数量。建议 4×3，更多方向用 8×3，实际网格适配时验证最小可读尺寸。
- 未提供倒计时但灯态有效：保留方向与灯态，秒数用 `—`。未知枚举使用中性色，不猜方向或灯态。
- 暂无信号 / 数据失效使用两个轻量空状态，不保留上次数字。不会为了保持视觉充实添加虚构的路口名、距离或车道。

## 实现契约与验证边界

实现已拆分为 `AmapTrafficLightProtocol`（纯协议解析）、`AmapTrafficLightAdapter`（单个共享接收器、有效期与来源关联）、`TrafficLightSnapshot`（Flutter 数据契约）和 `TrafficLightCard`（响应式展示）。完整实现与验证见 [0.6.9 记录](IP753_0_6_9.md)。

1. 两个协议分别解析，保留 raw direction/status；实测前不共用未经核对的枚举表。
2. 来源随用户关联的地图切换；停止导航、切换地图、空数组或明确无效信号时清空。官方广播没有来源包名字段，不通过 intent 自带的可伪造 extras 声称已验证发送方；仅作为导航提示使用。
3. 使用本机单调时钟计时。修改版 `ts` 可用于诊断，不直接依赖两端墙钟一致。
4. 有效期按真实广播周期确定。收到快照后可每秒更新数字，但不在零秒时自动切换红绿灯，不在失效后继续外推。
5. 只在当前可见卡片且数据有效时启动秒级 ticker；不重绘地图、桌面和全局底栏，不做高频发光动画，适应 IP753 的性能约束。

待上车核对：官方导航中 `60073` 是否实发、标准字段的枚举与可选绿灯值、修改版巡航数组是否实发、两方向是否同批更新、切换路口/退出导航的清空方式、实际更新间隔和断网行为。

设计验证：深浅色、单方向、多方向和两个空状态均已导图；4 项布局检查通过（画布尺寸、卡片内部边界、卡片外部边界、示例标记），浏览器无运行异常。实现阶段另有 Flutter 组件、Java 协议和 Android 9 模拟器验证，没有将模拟数据当成实车接收成功。

## 复现

```sh
/tmp/uni-apk-venv/bin/python tools/analyze_amap_traffic.py ../amap
node tools/render_traffic_lights.mjs
```

静态分析原始输出位于被 Git 忽略的 `analysis/raw/amap/`；Git 仅管理自写工具、精简事实与设计，不提交第三方 APK 或整包反汇编。
