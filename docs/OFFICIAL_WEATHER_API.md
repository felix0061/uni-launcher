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

注册后原服务延迟10秒推送当前数据，后续沿用原服务的更新节奏。`OfficialWeatherAdapter` 的**当前天气**只订阅这条回调，不修改原车数据或自行请求定位。温度含负数/零值，异常值、超大载荷、缺少城市的数据均不会伪造成有效天气。代码转换只适用于该包，不能与高德或QWeather代码混用。昼夜按原包的06:00–18:00规则显示。

`LauncherRuntime` 在进程内只持有一个适配器，多个Flutter窗口共享同一数据。原服务只保留一个客户端回调，所以没有在窗口关闭时盲目发送transaction 2清除可能已被另一个客户端替换的回调。绑定和数据随进程生命周期释放。

天气卡片和顶部状态共用 `WeatherSnapshot` 与已有全套天气图标；实际没有数据时显示等待/不可用原因。同步回调的时间不是气象观测时间，UI不宣称分钟级天气新鲜度。

实车已收到有效城市、22°C、晴（code `00`），与演示数据路径独立。尚未验证一小时更新、定位切城、长时间断网及休眠后的服务恢复；这些不得由一次有效回调推断为通过。

## 多日预报与地区匹配（0.6.5）

当前已核对的原车回调没有多日字段。详情中的七日预报单独请求 Open-Meteo，`forecastSource/forecastLocation/forecastCityFallback` 明确来源和地区，不将第三方预报写成原车数据。参数依据：[地理编码接口](https://open-meteo.com/en/docs/geocoding-api)、[预报接口](https://open-meteo.com/en/docs)。

实测查询“闵行区”“闵行”没有返回地点，旧实现只查区名且失败后等待 30 分钟。0.6.5 同时保留 `area/city`（例如闵行区/上海市）；依次查询原名、去行政后缀的名称和可用的拉丁名称，候选按所属省市校验。接口支持的 qualifier 是国家或一级行政区，不把任意完整地址直接拼成查询。

同音不同汉字不视为同一地点；普通村落/居民点也不能顶替行政区县。同属上海的“民兴”不应被识别成“闵行”。找不到区县时只能退回已确认所属的城市，并在详情标注“城市预报”；“上海市场社区”不匹配“上海”。换城会清理旧地区预报，过期异步回调不能覆盖新地区数据。

请求失败在 60 秒后允许自动重试；成功的后台重复请求间隔 30 分钟，打开详情仍可触发刷新。失败区分位置未匹配、DNS/网络、超时和其他错误，不统一伪装为未联网。`python3 tools/test_weather_location.py` 离线检查省市消歧、后缀、拼音、同音村落、非法坐标、城市回退和网络失败边界。
