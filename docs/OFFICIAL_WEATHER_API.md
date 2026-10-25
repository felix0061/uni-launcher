# IP753 官方天气接入

来源是实车 `/system/app/XCHome/XCHome.apk`，包 `com.ecarx.smartcloud`，版本 `V2023-08-03_3840bdd`。官方 Launcher 的天气卡片 Provider 同样属于该包。原始 APK/反汇编只保留在本地忽略目录，不打入发布包或源码提交。

`ecarx.home.service.CoreService` 声明了 action `ecarx.intent.action.smartcloud.core.service`。其 Binder descriptor 为 `ecarx.home.IWeatherCallback`：transaction 1 接收一个 callback Binder，返回注册 boolean；transaction 2 是取消注册。callback descriptor 为 `ecarx.home.IWeatherInfo`，transaction 1 接收 JSON 字符串。

`CoreService.g()` 的字段经过字节码与实车回调核对：

| 字段 | 含义 |
|---|---|
| `hasWidget` | 原车是否已添加天气 Widget，不是天气数据有效性开关 |
| `area` | 区域名称 |
| `city` | 城市名称 |
| `code` | 本包的天气代码，资源名 `ic_weather_00`、`ic_weather_01` 等 |
| `temprature` | 原包拼写如此；带摄氏度后缀的温度字符串 |

注册后原服务延迟10秒推送当前数据，后续沿用原服务的更新节奏。`OfficialWeatherAdapter` 只订阅这条回调；不自行请求定位、调用第三方天气接口或修改原车数据。温度含负数/零值，异常值、超大载荷、缺少城市的数据均不会伪造成有效天气。代码转换只适用于该包，不能与高德或QWeather代码混用。昼夜按原包的06:00–18:00规则显示。

`LauncherRuntime` 在进程内只持有一个适配器，多个Flutter窗口共享同一数据。原服务只保留一个客户端回调，所以没有在窗口关闭时盲目发送transaction 2清除可能已被另一个客户端替换的回调。绑定和数据随进程生命周期释放。

天气卡片和顶部状态共用 `WeatherSnapshot` 与已有全套天气图标；实际没有数据时显示等待/不可用原因。同步回调的时间不是气象观测时间，UI不宣称分钟级天气新鲜度。

实车已收到有效城市、22°C、晴（code `00`），与演示数据路径独立。尚未验证一小时更新、定位切城、长时间断网及休眠后的服务恢复；这些不得由一次有效回调推断为通过。
