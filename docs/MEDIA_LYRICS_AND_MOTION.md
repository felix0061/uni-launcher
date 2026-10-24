# 歌词通道与桌面动效

## 本地 APK 核对

仅分析用户提供的两个 APK，没有连接车机，也没有访问歌词网站。

- 官方 `ecarx.launcher3` 的 DCY11 配置把音乐卡片交给 `ecarx.xsf.mediacenter/ecarx.xsf.mediacenter.widget.MediaWidgetProvider1x2`。`ScalesLauncherAppWidgetHostView.onClickEvent` 向这个 Provider 发出 `ecarx.launcher3.widget.MediaUpdate`，没有歌词 extra，也未读取返回值。该 action 是更新请求，不能当作歌词推送。
- 官方样本业务反汇编与 DEX 字符串未命中 `lyric/lyrics/lrc/歌词`，未找到直接读取歌词的实现。外部媒体 Widget 是否支持歌词、如何取词，需要媒体中心 APK 或实车继续核对。
- 嘟嘟包含按播放器适配的歌词链路。网易云车机 SDK 的 `getLrc` 路径从 MediaMetadata 读取 `android.media.metadata.LYRIC`；QQ 车机 `update_lyric` 来自专用 JSON 广播，另有播放器缓存、会话事件及在线补词。此版本仅兼容明确文本 metadata/extras，不移植未核对的私有广播或缓存路径。

可复核的本地证据：

| 材料 | 位置 |
| --- | --- |
| 官方媒体默认 Widget | `analysis/raw/official/xml/res/xml/dcy11_widgetpage_default.xml` |
| 官方更新请求 | `analysis/raw/official/bytecode.txt` 的 `ScalesLauncherAppWidgetHostView.onClickEvent`，约 144939 行 |
| 嘟嘟网易云歌词字段 | `analysis/raw/dudu/bytecode.txt`，约 851765 行 |
| 嘟嘟 QQ 车机歌词分支 | `analysis/raw/dudu/bytecode.txt`，约 202696 行 |

`analysis/raw/` 是本地只读反汇编产物，被 Git 忽略；[APK 分析](APK_ANALYSIS.md)及[证据索引](../analysis/evidence.json)记录样本身份。官方样本版本晚于本车固件，不能认为每个接口都在本车存在。

## 当前实现

`MediaAdapter` 订阅当前媒体会话 metadata、播放状态和 extras 更新，读取有界文本字段：`android.media.metadata.LYRICS`、`android.media.metadata.LYRIC`、`lyrics`、`lyric`、`lrc`。这些是候选字段，并非 Android/领克统一歌词标准。`lyricsSource` 明确为 `media-session` 或 `demo`。

同时输出播放位置、时长、速度、采样时间和位置是否已知。原生先用 Android 单调时钟校正播放位置，Flutter 再按快照时间推进；暂停不推进，回调后重新定位，未知进度不猜测同步。

- `Lyrics` 解析 LRC 的多时间标签、毫秒精度和 offset，按时间二分定位；普通文本保留手动滚动，不虚构行时间。
- `LyricsView` 由音乐卡片、底栏和音乐详情复用。当前行采用主题色；有时间轴时自动滚动，详情保留前后行。无歌词明确显示空态，切歌无词时清掉旧词。
- 当前歌曲只接受源主动提供的文本，不请求网络歌词，不读取播放器私有缓存，不将外部 Widget 的展示等同于可提取字段。模拟器示例歌词为项目自写文本。
- 进度条改为实际会话快照驱动，不再固定写死为示例 00:46。

## 桌面切换

设置新增「切换动效」：无动画（默认）、淡入淡出、横向滑动。点击页码或左右轻扫均可切换；只有卡片工作区变化，状态栏与底栏固定。偏好随布局一同持久化，旧配置默认无动画。编辑时停用动效，系统减少动态效果时直接切换。

## 验证与车机待办

组件测试覆盖 LRC、多时间标签、offset、暂停/速度/时长、前后跳转、歌词清空、翻屏保存、手势、固定底栏和减少动态效果。Android 9 集成用自建 MediaSession 测试源验证歌词/进度经过 Java → Flutter 的通道；该测试源不是原厂媒体中心。

上车后按实际播放源比较歌曲 ID、歌词类型、进度、暂停、切歌和 seek。原厂媒体中心如未暴露这些字段，需继续分析其 APK/依赖或增加经过核对的专用适配，不能把当前候选兼容路径写成原厂歌词已验证。
