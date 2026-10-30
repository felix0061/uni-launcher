# UNI 桌面 · 语音控制功能方案

> 目标设备：领克 05 IP753（ecarx 平台，低性能车机）
> 项目形态：Flutter（UI/壳）+ Android 原生 Java（`LauncherRuntime` 数据源 + `MainActivity` 桥）
> 版本基线：`app/pubspec.yaml` 0.6.19+33；`OfficialCarContract` DCY11/IP753 契约

---

## 0. 需求清单（含追加项）

1. 全局唤醒（任意界面可用，包括非桌面应用）
2. 控制车辆功能：空调、氛围灯、音乐（座椅、导航作为顺带扩展）
3. 车机性能低，必须对性能友好
4. 使用「小智项目」的台湾腔语音
5. 设置里可开关，**默认关闭**，关闭后该服务彻底不运行
6. 支持本地简单指令 + 云端大模型
7. **（追加）支持多音色、支持音色定制**
8. **（追加）支持方控语音按钮激活**（方向盘语音键 = 按键唤醒，与唤醒词并列的第二种激活方式）

---

## 1. 现状盘点（可直接复用的资产）

| 资产 | 位置 | 复用方式 |
|---|---|---|
| 命令分发总线 | `LauncherRuntime.handleOnMain()` | 语音意图最终转成同一个 `action/value/zone` 动作 |
| UI 命令词汇表 | `LauncherController.command()` | 语音与触摸共用同一套动作，天然一致 |
| 车辆读写契约 | `OfficialCarContract` / `OfficialCarCommand` / `OfficialCarReader` | 空调/座椅直控；氛围灯在此扩展 |
| 媒体控制 | `MediaAdapter`（`toggle-play/previous/next/seek`） | 音乐类语音直接调用 |
| 全局服务先例 | `GlobalDockService` + `GlobalDockBootReceiver` | 语音前台服务照此模式实现「全局 + 自启」 |
| 音频采集经验 | `audio/SpectrumBridge`（已用 `RECORD_AUDIO`） | 16k 单声道 `AudioRecord` 可借鉴 |
| 快照/合帧机制 | `LauncherRuntime.publish()`（80ms 合帧、增量游标） | 语音状态并入快照，不额外刷 UI |
| 权限 | `AndroidManifest.xml` 已有 `RECORD_AUDIO`/`FOREGROUND_SERVICE`/`RECEIVE_BOOT_COMPLETED`/`MODIFY_AUDIO_SETTINGS`/`INTERNET` | 无需新增基础权限 |
| 设置面板 | `RuntimeSettings`（`integration_settings.dart`） | 开关/音色入口加在这里 |

**缺口**：氛围灯目前无直控契约；音量无独立 action（走系统 `AudioManager`）；语音引擎本身不存在。

---

## 2. 总体架构

```
┌───────────────────────────── 车机喇叭 / 麦克风 ─────────────────────────────┐
│                                                                           │
│  ┌──────────────┐   PCM   ┌───────────┐ 唤醒   ┌──────────────┐          │
│  │ AudioCapture  │────────▶│ WakeWord   │───────▶│ 识别态(短时)  │          │
│  │ 16k 单声道    │         │ (KWS)      │        └──────┬───────┘          │
│  └──────────────┘         └───────────┘               │ VAD 断句          │
│                                                        ▼                   │
│                                            ┌───────────────────┐          │
│                                            │ ASR（本地小模型）   │          │
│                                            └────────┬──────────┘          │
│                                                     ▼                      │
│                                    ┌──────────────────────────────┐       │
│                                    │ NLU 两级：                     │       │
│                                    │  L1 本地规则/槽位（离线）      │       │
│                                    │  L2 云端大模型 function call  │       │
│                                    └──────────────┬───────────────┘       │
│                                                   ▼                        │
│                      结构化意图 {action, value, zone, reply}               │
│                                                   │                        │
│        ┌──────────────────────────────┬───────────┴────────────┐          │
│        ▼                              ▼                        ▼          │
│ ┌───────────────┐          ┌────────────────────┐    ┌──────────────┐     │
│ │ 车辆/氛围灯    │          │ 媒体/导航/应用      │    │  TTS 引擎      │     │
│ │ (复用 command) │          │ (复用 command)      │    │  多音色+定制   │     │
│ └───────────────┘          └────────────────────┘    └──────────────┘     │
└───────────────────────────────────────────────────────────────────────────┘
```

**关键决策：语音引擎全部放原生（Android 侧），不进 Flutter。** 理由：

1. 全局唤醒需要后台服务常驻 `AudioRecord`，原生 `Service` 才可靠；
2. 车机性能敏感，原生可精确控制采样率、线程优先级、CPU 亲和与内存；
3. 复用 `LauncherRuntime` 的命令分发，语音→动作→车辆/媒体**零 Flutter 桥接**，延迟最低。

Flutter 只负责：设置开关、音色选择/定制 UI、以及通过 `voice` 快照展示语音状态（唤醒中/识别中/回复中）。

---

## 3. 需求逐条落地方案

### 3.1 全局唤醒（需求 1）

- 新建 `voice/VoiceAssistService`（`Service`，`startForeground`），仿照 `GlobalDockService` 的生命周期。
- 唤醒引擎选型（低性能车机 → 轻量 KWS）：

| 方案 | 说明 | 结论 |
|---|---|---|
| **sherpa-onnx KWS**（k2-fsa） | ONNX 运行时，自带 VAD(silero)、ASR、TTS，一套依赖覆盖三件事，Apache-2.0 | **首选** |
| Porcupine（Picovoice） | 中文唤醒词开箱即用，商用授权，需联网激活密钥 | 备选 |
| openWakeWord | TFLite，开源，默认英文，中文需自训 | 备选 |

- 唤醒词预置一个「你好 小U」（不自训练阶段不做运行时任意替换，详见 §9.1）。KWS 模型自训：sherpa-onnx / k2-fsa keyword-spotting 小模型，int8 量化目标 <2MB；备选 Porcupine 自定义中文唤醒词。
- 唤醒后进入**识别态（默认 8s 超时）**，超时或执行完回到监听态；识别态结束即停止录音，避免常驻采集。
- 「全局」由前台服务保证：开机自启（扩展现有 `GlobalDockBootReceiver` 或新增 receiver，仅当开关开启时拉起），跨应用可用。

### 3.2 车辆控制：空调 / 氛围灯 / 音乐（需求 2）

语音意图 → 复用现有 `command()` 动作（见下表）。氛围灯与音量是缺口，需新增。

| 语音意图示例 | action | value / zone | 现状 |
|---|---|---|---|
| 打开/关闭空调 | `climate-power` | — | ✅ 已有 |
| 主驾/副驾温度调高/调低 | `temp-up` / `temp-down` | zone=`left`/`right` | ✅ 已有 |
| 风量调大/调小 | `fan-up` / `fan-down` | — | ✅ 已有 |
| 开冷气 / 自动空调 / 内循环 | `climate-mode` | `ac`/`auto`/`recirc` | ✅ 已有 |
| 座椅加热 1/2/3 档 / 关 | `seat-heat` | zone=`left`/`right`, value=`0..3` | ✅ 已有 |
| 座椅通风 1/2/3 档 / 关 | `seat-vent` | zone=`left`, value=`0..3` | ✅ 已有 |
| 播放 / 暂停 / 上一首 / 下一首 | `toggle-play` / `previous` / `next` | — | ✅ 已有 |
| 音量调大/调小/静音 | `volume-up`/`volume-down`/`volume-mute` | — | ⚠️ 新增（原生 `AudioManager`） |
| 氛围灯 颜色/亮度/模式 | `ambient-light` | value=`color\|brightness\|mode` | ⚠️ 新增 |

**氛围灯新增路径**（照 `OfficialCarCommand` 纯命令模式扩展）：

1. `OfficialCarContract` 增加氛围灯 `FUNCTION` / `PA_*` 常量（实车抓包后核对 function ID，沿用现有「仅记录证据、不经验证不发命令」的纪律）；
2. `OfficialCarCommand` 增加 `ambient-light` 的 `key()` 与 `plan()`；
3. `OfficialCarReader` 增加读回/写回映射；
4. `LauncherRuntime.handleOnMain` 增加 `ambient-light` 分支；
5. 兜底：契约未验证前，语音「调氛围灯」先走 `open-official` 拉起原车氛围灯应用，验证后再直控。

> 说明：`recirc` 目前是 toggle 语义（内/外循环都发 `climate-mode`=recirc）。语音要显式「内循环/外循环」时，建议新增 `recirc-set` + `enabled` 明确设值，避免一句话内 toggle 方向不可预期。

### 3.3 性能友好（需求 3）

**分层运行成本**（设计目标，4 核 A53 级别车机）：

| 运行层 | CPU | 说明 |
|---|---|---|
| 关闭（默认） | **0** | 服务不启动、不录音、不联网、无模型常驻 |
| 仅唤醒（KWS） | 单核 ~3–8% | 小模型 + 8bit 量化，后台低优先级线程 |
| 识别中（ASR+NLU 本地） | 短时峰值 | 仅唤醒后 8s 内，用完即停 |
| 云端大模型 | 按需 | 仅复杂句触发，可单独关闭 |

具体手段：

1. **默认全关 = 零开销**（开关持久化 `voiceEnabled=false`，服务直接不启动）。
2. 唤醒阶段只跑 KWS，无任何网络长连接；录音 16kHz/16bit 单声道，buffer 短（~20ms 帧）。
3. 本地 ASR 用 `sherpa-onnx` 的 `SenseVoice-small`（或 Zipformer 中文小模型），单次短句识别；模型按需加载，不用即释放。
4. 本地 NLU 是纯规则/槽位（无模型），内存与 CPU 可忽略。
5. TTS 播报期间**暂停 KWS**（防自唤醒、省 CPU）；**音乐/导航播放期间 KWS 降低灵敏度**（提高唤醒阈值，见 §9.3），配合方控按键兜底。
6. 语音状态并入现有 `LauncherRuntime.publish()` 合帧与增量游标，**不额外触发 Flutter 整树重建**。
7. 监听 `onTrimMemory`/`onLowMemory`（`MainActivity` 已有此回调）暂停 KWS；车机发热/低内存时自动让路。
8. 常驻内存预算：KWS 模型 <5MB，ASR 模型 <40MB，合计控制在 **<50MB**，TTS 音色模型按需加载。

### 3.4 小智台湾腔（需求 4）

「小智项目」（xiaozhi-esp32 / xiaozhi-esp32-server）的台湾腔听感主要来自两类 TTS 提供方，方案直接对齐同一批音色源，保证听感一致：

| 提供方 | 音色示例 | 特点 |
|---|---|---|
| **Edge-TTS（微软，云端免费）** | `zh-TW-HsiaoYuNeural` / `zh-TW-HsiaoChenNeural` / `zh-TW-YunJheNeural` | 台湾腔最直接、延迟低、零自建成本 |
| 自建 CosyVoice2（小智 server 同款通道） | 台湾腔参考音色 / 用户克隆音色 | 可克隆、可定制，与「小智」生态同源 |
| 豆包 TTS（可选） | 台湾腔音色 | 需要火山引擎密钥，音质好 |

默认音色：`zh-TW-HsiaoYuNeural`（台湾腔），作为「小智听感」的基线。

### 3.5 设置开关、默认关闭、关闭彻底停（需求 5）

- 持久化 `voiceEnabled`（默认 `false`）到 `launcher` SharedPreferences。
- 设置 UI 加在 `RuntimeSettings`（`integration_settings.dart`）新增「语音助手」`DesignSwitchTile`，键值如 `ValueKey('voice-enabled')`。
- **开启**：写入 pref → 启动 `VoiceAssistService` → 首次申请 `RECORD_AUDIO`。
- **关闭**：`stopService` → 释放 `AudioRecord` → 释放模型内存 → 断开网络 → 快照移除 `voice` 状态。
- 开机自启只在 `voiceEnabled==true` 时拉起服务，保证「关 = 彻底不运行」。
- 快照新增 `voice` 块：`{enabled, listening, state, available}`，Flutter 据此显示状态徽标。

### 3.6 本地简单指令 + 云端大模型（需求 6）

两级 NLU，**优先本地、云端兜底**：

```
识别文本
   │
   ▼
L1 本地规则 NLU（槽位：动作/对象/数值/区域/颜色）
   │ 命中 ──▶ 直接执行 command()
   │
   └ 未命中 ──▶ L2 云端大模型（Qwen / Doubao / DeepSeek，function calling）
                     │ 输出结构化意图 {action, value, zone}
                     ▼
                  映射到同一 command() 词汇表，执行
                  闲聊/问答 → 直接返回文本 → TTS 播报
```

- L1 覆盖高频确定性指令（空调/风量/座椅/音乐/氛围灯），**离线可用、零延迟**。
- L2 只处理复杂/自由表达与闲聊；两者可**分别开关**（如「仅本地」模式，彻底不联网）。
- 云端 function calling 的 schema 就是 L1 的意图 schema，保证本地/云端**执行路径统一**。
- **职责边界（§9.5）**：车控类意图只由 L1 本地 NLU 产生并执行；L2 云端只做闲聊/问答/信息查询，不输出车控 action。

### 3.7 多音色 + 音色定制（追加需求 7）

**多音色**：维护音色清单（内置 + 云端），每个音色含 `voiceId / 名称 / 来源 / 试听`，设置面板可预览并选择。清单示例：

| voiceId | 名称 | 来源 |
|---|---|---|
| `tw-hsiaoyu` | 小智台湾腔（默认） | Edge-TTS zh-TW |
| `tw-hsiaochen` | 台湾腔·晓臻 | Edge-TTS zh-TW |
| `cn-xiaoxiao` | 普通话·晓晓 | Edge-TTS zh-CN |
| `cn-yunxi` | 普通话·云希 | Edge-TTS zh-CN |
| `clone-xxxx` | 用户克隆音色 | CosyVoice2 |
| `local-vits` | 本地离线音色 | sherpa-onnx VITS/MeloTTS |

**音色定制**分两级：

1. **参数定制**（零门槛）：语速（0.6x–1.6x）、音调（±20%）、音量。Edge-TTS 原生支持 `rate/pitch/volume`，即时生效。
2. **声音克隆**（进阶，与「小智」同源）：
   - 用户在设置里录制/上传 5–10s 参考音频；
   - 上传到自建 CosyVoice2 服务（或走 CosyVoice API）生成 `voiceId`；
   - 返回并加入音色清单，之后所有 TTS 播报均可选用该克隆音色；
   - 参考音频存 `filesDir/voices/`，`voiceId` 存 pref；无网络时降级为预置音色。

TTS 播放统一走 `AudioTrack` + `AudioFocus`（`MODIFY_AUDIO_SETTINGS` 已声明），播报时按车机混音策略压低音乐/导航音量。

### 3.8 方控语音按钮激活（追加需求 8）

方向盘语音键是「按键唤醒」，与 3.1 的「唤醒词」**并列、共用同一条识别流水线**：按键按下 → 直接进入识别态 → VAD/ASR/NLU/执行/TTS，与唤醒词唤醒后的流程完全一致，只是跳过了 KWS。

**现有按键链路盘点**（本项目已具备的资产）：

| 资产 | 位置 | 作用 |
|---|---|---|
| 方控媒体键 | `MediaAdapter` 的 `steeringSession`（`MediaSession` + `FLAG_HANDLES_MEDIA_BUTTONS`） | 上一首/下一首/播放暂停已走标准 MediaSession 派发 |
| 悬浮窗按键 | `GlobalDockService.OverlayWindow` 的 `dispatchKeyEvent` | 现有返回键拦截先例 |
| HOME 按键 | `MainActivity`（`FlutterActivity.dispatchKeyEvent`） | 桌面前台时收 KeyEvent |
| 系统权限 | `INJECT_EVENTS`（manifest 已声明） | 可反射注册全局输入监听 |

**方控语音键接收路径（按可靠性排序，实车逐步验证）：**

1. **路径 A — 标准键拦截（首选，零系统依赖）**：在 `MainActivity` + `GlobalDockService` 的 overlay view 里拦截 `KeyEvent.KEYCODE_VOICE_ASSIST`（219，等同 `KEYCODE_ASSIST`），以及车机可能的自定义 keycode / `KEYCODE_SEARCH`(84)。实车用 `logcat`/`dumpsys input` 抓一次真实 keycode 后固化到常量表。
2. **路径 B — 全局输入监听（真正的「任意应用前台都可用」）**：项目是 platform 签名系统应用，反射向 `InputManagerService` 注册 `InputMonitor` 需要 `android.permission.MONITOR_INPUT`（signature，manifest 增补，见 §9.4），全局过滤语音键，命中即激活。若固件实现了 `android.car.input.CarInputService`，优先绑定它（最正规）。
3. **路径 C — 厂商按键服务/广播**：ecarx 固件可能把方控语音键发成定制广播或 `com.ecarx.xui.adaptapi` 按键回调，实车抓取后按需注册 receiver。
4. **路径 D — 兜底（桌面内激活）**：`MainActivity.dispatchKeyEvent` 拦截语音键，保证至少桌面/底栏场景可用；「全局」由 B/C 补齐。

**激活语义（可配置）**：

- **按压即说（PTT，默认推荐）**：按下进入识别态、再按（或松开）结束，像对讲机，最抗噪、最省 CPU。
- **按一下自动听**：单按进入识别态，VAD 自动断句结束（与唤醒词体验一致）。

**与唤醒词的关系**：

- 按键激活优先：按下时暂停 KWS，避免「按键 + 唤醒词」重复触发。
- 两种激活源共享同一 `VoiceAssistService.activate(source)` 入口，`source ∈ {wakeword, steering}`，快照里 `voice.source` 暴露给 UI 显示。

**注意**：车机系统可能自带语音助手会抢占该按键。作为 HOME/系统应用，需要确认按键分发的优先级；必要时在路径 B 用系统权限先消费该键，避免与自带助手打架。

---

## 4. 模块与文件落点

### 新增（Android `app/android/.../xyz/i4o/uni/launcher/`）

```
voice/
  VoiceAssistService.java     前台服务：生命周期、开关、权限、快照联动
  VoiceSettings.java          pref 封装：enabled/wakeWord/voiceId/speed/pitch/localOnly/cloudEnabled
  AudioCapture.java           16k 单声道 AudioRecord 采集
  WakeWordEngine.java         sherpa-onnx KWS 封装（唤醒词可替换）
  SteeringKeyListener.java    方控语音键监听（路径 A/B/C 统一入口，命中后 activate("steering")）
  LocalAsrEngine.java         sherpa-onnx SenseVoice-small 封装
  LocalNlu.java               纯规则/槽位 NLU（无 Android 依赖）
  CloudDialogueClient.java    云端大模型 function calling（HTTP/WebSocket）
  TtsEngine.java              多音色 + 参数定制 + 克隆音色 + AudioFocus 播放
  VoiceCommand.java           纯命令规划：意图 → action/value/zone（仿 OfficialCarCommand）
```

### 修改（Android）

| 文件 | 改动 |
|---|---|
| `LauncherRuntime.java` | 持有语音服务引用；`handleOnMain` 增 `voice-*` 动作；`buildSnapshot` 增 `voice` 块 |
| `MainActivity.java` | 语音权限回调（`RECORD_AUDIO`）复用到服务；`dispatchKeyEvent` 拦截方控语音键（路径 A/D） |
| `GlobalDockService.java` | overlay `dispatchKeyEvent` 拦截方控语音键（路径 A，跨应用前台可用） |
| `AndroidManifest.xml` | 声明 `VoiceAssistService`；如自启新增/扩展 boot receiver |
| `OfficialCarContract.java` | 增氛围灯 function ID 常量（实车验证后） |
| `OfficialCarCommand.java` | 增 `ambient-light` / `volume-*` 的规划 |
| `OfficialCarReader.java` | 增氛围灯读回/写回 |

### 新增（Flutter `app/lib/`）

```
model/voice_settings.dart        语音配置模型（音色/语速/音调/开关/状态）
widgets/voice_settings_panel.dart  设置面板（开关 + 音色选择 + 试听 + 定制）
```

### 修改（Flutter）

| 文件 | 改动 |
|---|---|
| `widgets/system_settings.dart` 或 `integration_settings.dart` | `RuntimeSettings` 增加口/开关 |
| `platform/native_gateway.dart` | 增 `voice-*` 动作透传（或并入现有 `action`） |
| `controller/launcher_controller.dart` | 增语音状态读取与便捷方法（可选） |

---

## 5. 一次完整交互时序（目标延迟预算）

```
激活（唤醒词 / 方控语音键，二选一）(0ms)
  → 提示音 + 进入识别态 (≤100ms)
  → 采集 + VAD 断句 (用户说完)
  → 本地 ASR (目标 ≤400ms 短句)
  → L1 NLU 命中 → command() 执行 (≤100ms)
       ├─ 成功 → TTS 短确认播报 (≤1.5s 首字)
       └─ 未命中 → L2 云端 (网络往返, 视网络)
             → 结构化意图 → command() 执行 + TTS 回复
  → 回监听态
```

---

## 6. 降级与容错

| 场景 | 策略 |
|---|---|
| 无网络 | 仅 L1 本地指令；TTS 降级本地音色或静默执行 |
| 未授权 `RECORD_AUDIO` | 开关引导授权；未授权则服务不启动 |
| 氛围灯契约未验证 | 语音先 `open-official` 拉起原车氛围灯，验证后直控 |
| TTS 播放自触发 | 播放期间暂停 KWS（回声自触发防护） |
| 内存/发热压力 | `onTrimMemory` 暂停 KWS，压力解除恢复 |
| 后台服务被车机省电策略回收 | 前台服务 + 关闭/重开自愈 + 开机自启 |

---

## 7. 落地里程碑（每阶段可交付、可回滚）

| 阶段 | 内容 | 交付物 |
|---|---|---|
| **M1 骨架** | 开关（默认关）+ 前台服务 + 唤醒词 + 方控语音键激活（路径 A/D）+ 单音色 Edge-TTS + 音乐/空调基础指令 | 可语音「暂停/下一首/温度调高」，可按方向盘键说话 |
| **M2 本地闭环** | 本地 ASR+NLU 全量命令 + 音量 + 氛围灯（含兜底） | 离线可用，全命令覆盖 |
| **M3 云端+音色** | 云端大模型 function calling + 多音色 + 语速/音调 + 声音克隆 | 自由对话 + 音色定制 |

---

## 8. 风险与注意

1. **氛围灯实车契约**：需要一次实车抓包/日志验证 function ID，沿用项目「未经验证不发命令」的纪律，先兜底后直控。
2. **车机省电策略**：不同固件对后台录音/前台服务的限制不同，需在目标 IP753 实车验证服务存活。
3. **方控语音键的 keycode 与分发路径未知**：必须先实车抓一次（`logcat`/`dumpsys input`）确认它是否映射为 `KEYCODE_VOICE_ASSIST`(219)、自定义码、还是厂商广播/服务，再锁定路径 A/B/C；且要确认不会与车机自带语音助手抢键冲突。
4. **隐私**：默认本地优先；云端大模型与云端 TTS 均应可独立关闭，云端音频上传需在设置里明确。
5. **回声自触发**：TTS 播报期间 KWS 暂停是低成本方案；若要求「打断说话」再考虑 AEC（会显著增 CPU，不推荐在该车机做）。
6. **模型体积**：sherpa-onnx 的 SenseVoice 模型按需加载、用完释放，避免与 Flutter 图标缓存争内存。

---

## 9. 优化规划（A/B 类修订）

> 依据代码评审结论与产品决策定稿。A 类为技术硬伤修正，B 类为体验/健壮性补强。

### 9.1 唤醒词：预置「你好 小U」（A1）

- 只预置一个唤醒词「你好 小U」，**不做运行时任意替换**（每个唤醒词是独立训练的模型）。
- KWS 模型自训：
  - 主选：sherpa-onnx / k2-fsa 的 keyword-spotting 训练（zipformer 系小模型），产出 int8 onnx，目标 **<2MB**。
  - 数据：多音色 TTS 合成正样本（数千条，覆盖语速/口音/男女）+ 真实车机底噪/音乐/导航播报增强；负样本取音乐、对话、导航、路噪。
  - 备选：Picovoice Porcupine 自定义中文唤醒词（免训练，但商用授权需评估）。
- `VoiceSettings.wakeWord` 字段保留，当前固定 `hello-xiaou`；未来扩展多唤醒词 = 多个模型文件，按字段加载。

### 9.2 生命周期：引用计数 + 按需保障（A2）

问题：`vehicle/media/weather` 等源跟随窗口 listener 启停（`addListener` 首接入才 `start`，`removeListener` 到空即 `stop`）。语音服务常驻但无窗口时，`command` 会拿到 `false`。

方案（推荐）：**引用计数式源生命周期**，语音保持「不常驻源、执行时才保障」：

```java
// LauncherRuntime 新增
private int sourceRefs = 0;

void acquireSources() {              // 0→1 时 start vehicle/media/weather/…
    onMain(() -> { if (sourceRefs++ == 0) startSources(); return null; });
}
void releaseSources() {              // 1→0 时 stop
    onMain(() -> { if (--sourceRefs <= 0) { sourceRefs = 0; stopSources(); } return null; });
}
// addListener/removeListener 改走同一计数器（首 listener = acquire，尾 listener = release）

// 语音专用入口：执行前后各包一层引用
void handleVoice(JSONObject request) {
    onMain(() -> {
        acquireSources();
        try { handleOnMain(request); } finally { releaseSources(); }
        return null;
    });
}
```

- 语音服务只调 `handleVoice()`，**不持有 listener** → 无窗口时不增加待机功耗。
- 执行命令的瞬间源必然就绪 → 解决「全局语音控车静默失败」。
- `acquire/release/handle` 全部主线程串行，无并发问题。
- 本 APP 为 platform 签名系统应用；此方案不需要特权，靠的是幂等 `start/stop` + 引用计数。特权（如 §9.4 的 `MONITOR_INPUT`）只用于方控按键等系统级能力。

### 9.3 抗干扰：音乐播放时降灵敏度（A3）

- KWS 输出为概率分数，**降灵敏度 = 提高唤醒阈值**：
  - `WakeWordEngine` 两档阈值：`normal`（默认）/ `noisy`（音乐或导航播报时更高）。
  - 音频场景信号：`MediaAdapter` 的 `playing` 状态 + `NavigationAudioAdapter` 播报状态 → 语音服务**轻量订阅**（不参与 §9.2 的源引用计数），状态翻转时切阈值。
- 设置项：`voiceWakeSensitivity ∈ {高/中/低}`，映射到 noisy 阈值档。
- 组合策略：音乐播放时「降灵敏度唤醒」为主、「方控按键」兜底——切歌/音量这类高频音乐指令，播放中用按键最可靠。

### 9.4 方控全局监听权限修正（A4）

- 全局输入监听（`InputManagerService.monitorInput` / `InputMonitor`）检查的是 `android.permission.MONITOR_INPUT`（signature），**不是 `INJECT_EVENTS`**（那是注入事件用的）。
- 本 APP 是 platform 签名：manifest 增 `<uses-permission android:name="android.permission.MONITOR_INPUT"/>` 后路径 B 才成立；`INJECT_EVENTS` 保留用于现有/未来的注入场景。

### 9.5 云端职责边界：车控只走本地（B5）

- 车控类意图（空调/风量/座椅/音乐/氛围灯/导航/音量/应用）**只由 L1 本地 NLU 产生并执行**。
- L2 云端 LLM **只做闲聊/问答/信息查询**，输出纯文本给 TTS，**不输出车控 action**。
- 收益：车控延迟固定（本地）、可靠、无隐私外泄；云端 function calling 保留但仅用于非车控查询（天气/百科），或直接砍掉。

### 9.6 TTS 混音：纳入导航混音策略 + 同播开关（B6）

- 设置项 `voiceTtsMixMode ∈ {duck(默认), coexist}`：
  - `duck`：播报时压低音乐/导航（`AudioFocus GAIN_TRANSIENT_MAY_DUCK`），播完恢复；
  - `coexist`：允许同播，TTS 原音量叠加，不请求/仅 MAY_DUCK 焦点。
- 与 `NavigationAudioAdapter` 统一：语音播报与导航播报**互斥排队**（导航优先，TTS 等待），避免双焦点打架；ducking 复用现有混音通道，不新开第二套。
- 播报结束 `abandonAudioFocus`，回到原混音状态。

### 9.7 麦克风抢占检测与恢复（B7）

- `AudioCapture` 监听录音焦点 + `AudioRecord` 错误回调：
  - 被抢占（蓝牙电话/微信语音/其他录音）→ 停 KWS，`voice.state=suspended`，波纹显示「麦克风占用」；
  - 释放 → 自动恢复 KWS。
- 实现：录音侧 `AudioManager` 焦点监听 + `AudioRecord.read` 连续空/错误检测兜底。

### 9.8 视觉反馈：优雅波纹，全局优先（B8）

- 形态（优雅，横屏底部居中）：呼吸光带 + 唤醒瞬间同心圆扩散，跟随状态：
  - 监听中：微光呼吸（24fps，省电）
  - 已唤醒/聆听：扩散波纹 + 「聆听中…」（60fps 仅唤醒瞬间，随后回落）
  - 识别中：波纹收缩 + 字幕
  - 回复中：波形随 TTS 起伏
  - 出错/占用：红色一次闪烁 + 文字
- 颜色随主题 accent（复用 `SurfaceStyle`）。
- 全局渲染，三级降级（按现有资产）：
  1. **复用 `GlobalDockService` 窗口**（首选）：波纹画进现有 dock 的 Flutter（`globalDockMain` 入口），`voice` 快照驱动，**零新增引擎、零额外授权**；
  2. dock 关闭但语音开启 → 独立轻量原生 overlay（纯 Canvas 呼吸波纹，**不建 Flutter 引擎**，省内存）；
  3. 桌面内 → 画在 `LauncherShell` 底部，复用 Flutter。
- 悬浮窗权限：`SYSTEM_ALERT_WINDOW` 已声明、dock 已用授权，波纹复用 dock 无新增权限；独立 overlay 沿用同一授权。

---

## 10. 实现进度（M2：sherpa-onnx 离线引擎 + Edge-TTS 多音色已接入）

> M1 用桩跑通全链路；M2 起接入 sherpa-onnx 真实 KWS/ASR + Edge-TTS 多音色。语音引擎按接口抽象，sherpa 不可用时自动降级到桩。

### 10.1 Android 侧（voice 包）

| 文件 | 职责 |
|---|---|
| `voice/VoiceBridge.java` | LauncherRuntime 依赖的最小接口，快照注入 voice 块 |
| `voice/VoiceSettings.java` | 配置落盘：开关/唤醒词/音色/语速音调/灵敏度/混音/连续对话/云端 |
| `voice/VoiceCommand.java` | 纯规则 NLU：文本 → action/value/zone/reply（车控只在这里产出） |
| `voice/VoiceEngine.java` | KWS/ASR/TTS 抽象 + `StubVoiceEngine` 桩 + `SystemTts`（系统 TTS 离线兜底） |
| `voice/SherpaVoiceEngine.java` | sherpa-onnx 真实引擎：KWS 唤醒词 + zipformer2-CTC 中文流式 ASR（全离线），RMS 断句 |
| `voice/VoiceTts.java` | 统一 TTS：sherpa VITS 离线合成（174 音色）为主，系统 TTS 兜底；离线模型在内部懒加载 |
| `voice/SherpaTts.java` | sherpa-onnx `OfflineTts` 封装：VITS 合成 → float PCM → AudioTrack + MAY_DUCK 焦点，后台线程合成 |
| `voice/VoiceModels.java` | 模型资产统一入口：assets/models → filesDir/models（带版本标记，仅首次拷贝） |
| `voice/EdgeTts.java` | **已停用**：微软 Sec-MS-GEC 升级 v2 后旧协议一律 403，代码仅留存作参考 |
| `voice/VoiceAssistService.java` | 前台服务 + 常驻录音线程 + 状态机 IDLE/LISTENING/THINKING/SPEAKING/UNAVAILABLE |

集成改动：
- `LauncherRuntime`：`attachVoice` / `handleVoice`（引用计数，§9.2）/ `mediaPlaying` / voice 快照块 / `voice-*` 与 `volume-*` 动作 / `adjustVolume`。
- `MediaAdapter.isPlaying()`：轻量播放态查询，供灵敏度联动。
- `MainActivity.dispatchKeyEvent`：方控语音键（KEYCODE_VOICE_ASSIST/ASSIST/SEARCH）激活（路径 D）。
- `AndroidManifest`：`MONITOR_INPUT`（§9.4）+ `VoiceAssistService` 声明。
- `app/build.gradle.kts`：JitPack `sherpa-onnx:v1.13.5` + OkHttp 4.12（Edge-TTS/云端），`ndk.abiFilters` 限 arm64-v8a/armeabi-v7a 控体积。
- 根 `build.gradle.kts`：`allprojects.repositories` 增 JitPack。

### 10.2 离线模型资产（`app/android/app/src/main/assets/models/`）

| 目录 | 模型 | 大小 | 用途 |
|---|---|---|---|
| `models/kws/` | sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20（int8） | ~8.7MB | 开放词表唤醒词「你好 小U」（`keywords.txt` 免训练） |
| `models/asr/` | sherpa-onnx-streaming-zipformer-small-ctc-zh-int8-2025-04-01 | ~25MB | 中文流式指令识别（zipformer2-CTC，RTF≈0.04） |
| `models/tts/` | vits-icefall-zh-aishell3（`model.onnx` 29MB + `lexicon.txt` 1.95MB + `tokens.txt` + 4 个 fst） | ~31MB | **离线语音合成，174 个音色**，8kHz |
| `models/vad/` | silero_vad.onnx | ~0.6MB | 预留（当前断句用 RMS，真机验证后可选换） |

> 选型说明：最初的双语 zipformer transducer（int8 ≈ 189MB）对低性能车机过大，已替换为 25MB 的 CTC 中文小模型；唤醒词放弃自训练，改用开放词表 KWS + `keywords.txt`（`n ǐ h ǎo x iǎo y ōu @你好_小优`，发音等价「你好 小U」）。
>
> TTS 选型：`vits-icefall-zh-aishell3` 是「音色多 + 体积小」的最优解（31MB / 174 说话人；同批候选 eula 115MB、fanchen-C 113MB）。`rule.far` 172MB 是文本规则库，不随包分发。模拟器实测：引擎加载 0.85s，单句合成 0.2–0.4s，采样率 8kHz（电话音质，车舱够用）。

### 10.3 Flutter 侧

| 文件 | 职责 |
|---|---|
| `model/voice_settings.dart` | voice 快照模型 + 离线音色编号（0..173）；`voiceCatalog` 为已停用的 Edge-TTS 历史表 |
| `widgets/voice_wave.dart` | 波纹画布：聆听扩散环 / 识别脉冲 / 回复声波 / 待机微光 |
| `widgets/voice_overlay.dart` | `VoiceOverlay`（桌面底部大波纹）+ `VoiceDockGlow`（dock 顶部呼吸光带） |
| `widgets/voice_settings_panel.dart` | 设置面板：开关/音色/语速音调/灵敏度/混音/连续对话/云端 |
| `assets/icons/mic.svg` | 麦克风图标（32×32 line 风格） |

挂载：`system_settings.dart`（面板，系统设置页）、`launcher_shell.dart`（桌面波纹，§9.8 第 3 级）、`bottom_dock.dart`（dock 光带，§9.8 第 1 级）。

### 10.4 当前可运行行为

- 总开关默认关，关闭时服务不启动、不录音。
- 开启后常驻录音：IDLE 态持续做唤醒词检测（「你好 小U」），命中自动进入聆听。
- 方控语音键与唤醒词两条激活路径共用同一状态机。
- 聆听（RMS 断句 + 噪声门控）→ sherpa 流式识别 → 本地 NLU → 执行 → TTS 回复 → 连续对话（8s 超时回待机）。
- TTS 回复走 **sherpa VITS 离线合成**（174 个音色，speakerId + 语速实时生效），全程不联网；系统 TTS 仅在离线引擎未就绪时兜底（车机多无系统引擎，无声音但不崩）。
- 设置面板可滑动挑选音色并「试听」；服务未启动时试听会临时加载离线模型后播报（首次需拷贝 31MB）。
- 播报期间请求 MAY_DUCK 音频焦点，系统自动压低音乐/导航（§9.6 duck）。
- 音乐/导航播放时有效灵敏度降一档（A3）；瞬时噪声（<160ms）被过滤。
- 连续对话后续轮：噪音静默续听、非车控文本静默结束，不打扰乘客谈话。
- 模型加载失败自动降级桩（`snapshot().engine` = `stub`），功能不崩。
- 波纹/光带跟随状态，非激活态停表省电。

### 10.5 TODO

1. 真机标定 KWS 唤醒率/误触发：调 `keywords.txt` 的 `:boost #threshold`（当前 2.0 / 0.35）。
2. 真机验证 RMS 断句效果，必要时换 silero VAD（`models/vad/` 已就位，`Vad.isSpeechDetected()`）。
3. 离线 TTS 首字延迟优化：长句按标点切分流式合成（当前 one-shot，全句合成完再播）。
4. 全局 InputMonitor 按键（§9.4，路径 B）与麦克风抢占自动恢复（B7）。

### 10.6 云端大模型接入（M3，已完成）

- `voice/CloudLlm.java`：OpenAI 兼容 `/chat/completions`，OkHttp 异步，callTimeout 12s。
- 路由：`VoiceCommand` 规则命中 → 本地执行（快、离线）；未命中且 `cloudReady()` → 云端兜底。
- 云端返回分两类处理：
  - 白名单 JSON `{"action","value","zone","reply"}` → 校验 `ALLOWED_ACTIONS` 后走同一 `execute()` 通道；
  - 自然语言 → 直接 TTS 播报（闲聊/问答）。
- **安全边界不变（§9.5）**：动作白名单只含 16 个既有车控 action，模型编造的动作一律丢弃，绝不透传给车辆接口。
- 上下文：`MAX_HISTORY = 8`（4 轮），仅存服务内存，服务销毁即清。
- 配置项：`voiceCloudEndpoint / voiceCloudModel / voiceCloudApiKey`，默认预置 DeepSeek，只需填 Key。
- 面板提供 DeepSeek / 通义千问 / OpenAI / 硅基流动 预设 + 自定义 endpoint/model。
- 打开 `voice-cloud` 会同步解除 `localOnly`，避免两个开关互相抵消。
- 失败策略：网络异常时首轮播报「网络不太好」，连续对话中静默收尾，不反复打扰。
- release 包需关闭 R8 混淆（`isMinifyEnabled=false`），否则 sherpa JNI 字段反射失败导致引擎降级（详见 proguard-rules.pro 注释）。

## 11. 拆包：语音作为独立安装的 App（M4）

### 11.1 动机

模型体量决定了不能塞在桌面包里：唤醒词 + 识别 + 离线合成的模型加起来约 166MB。
不需要语音的用户没理由为它多下一百多兆，因此语音整体拆成独立 APK，桌面只留一个总开关。

| 包 | applicationId | 内容 | arm64 release 体积 |
| --- | --- | --- | --- |
| 桌面 | `xyz.i4o.uni.launcher` | Flutter UI + 车控 + 媒体；**不含任何语音模型** | 21.3MB（原 102.8MB） |
| 语音 | `xyz.i4o.uni.voice` | KWS/ASR 模型 + 离线 TTS 模型 + 设置界面 + 前台服务 | 168.7MB |

桌面侧因此可以彻底移除 `sherpa-onnx` 与 `okhttp` 依赖，安装包少掉一整套原生库。

### 11.2 分工

- **语音 App**：唤醒词监听、ASR、TTS（本地/火山两种引擎）、连续对话、噪声判定、全部语音设置。
- **桌面 App**：车辆与媒体接口、车控执行、一个总开关 + 跳转入口。

车控接口只在桌面侧，所以语音识别出动作后要跨进程请桌面执行——这条边界沿用 §9.5：
云端与语音模块都不直接碰车辆接口。

### 11.3 跨进程协议（显式广播 + signature 权限）

两端同证书签名（`uni-debug.keystore`），广播都带 signature 级权限，第三方应用发不进来。

```
语音 → 桌面   xyz.i4o.uni.launcher.VOICE_EXEC         有序广播，回 result=ok/fail
语音 → 桌面   xyz.i4o.uni.launcher.VOICE_MEDIA_QUERY  有序广播，回 playing=1/0
语音 → 桌面   xyz.i4o.uni.launcher.VOICE_STATE        状态上报（state/wakeWord/engine/tts*）
桌面 → 语音   xyz.i4o.uni.voice.CONTROL               op=enable/disable/refresh/activate
```

- `xyz.i4o.uni.launcher.permission.VOICE` 保护桌面侧 `VoiceExecReceiver`；
  `xyz.i4o.uni.voice.permission.VOICE` 保护语音侧 `VoiceControlReceiver`。
- 开关状态由语音 App 持有（单一事实源），桌面开关只是发指令 + 显示它上报的状态，不会两边不同步。
- 桌面没装 / 语音没装都能正常降级：广播收不到就按失败处理，不抛异常。
- 方控语音键仍由桌面 `dispatchKeyEvent` 捕获（VOICE_ASSIST / ASSIST / SEARCH），转成 `CONTROL{op=activate}`。

### 11.4 TTS 双引擎（可自选）

设置里二选一，`TtsEngine` 接口屏蔽差异，`VoiceTts` 负责路由与兜底。

| 引擎 | 实现 | 特点 | 依赖 |
| --- | --- | --- | --- |
| 本地离线 | `SherpaTts`（sherpa-onnx VITS `vits-zh-hf-eula`） | 22.05kHz、804 个音色、完全离线 | 模型随包 132MB |
| 火山引擎 | `VolcanoWsTts` / `VolcanoTts` | 音质与音色数量最强，需联网与密钥 | 无模型 |

火山引擎支持三种协议，按账号开通的产品切换：

- **双向流式（默认，推荐）** `wss://openspeech.bytedance.com/api/v3/tts/bidirection`
  请求头 `X-Api-Key` / `X-Api-Resource-Id`（默认 `seed-tts-2.0`）/ `X-Api-Connect-Id`；
  文本边送、音频边回，收到第一块 PCM 就开播，首字延迟约等于一次 RTT。
  走火山自定义二进制帧（4 字节头 + event + session + payload），编解码内置于 `VolcanoWsTts`。
- **单向 HTTP** `https://openspeech.bytedance.com/api/v3/tts/unidirectional`，逐行 JSON，每行一段 base64 PCM。
- **经典 v1** `https://openspeech.bytedance.com/api/v1/tts`，`Authorization: Bearer;{token}` + `cluster` + `voice_type`。

三条链路共用同一套播放收尾逻辑：`AudioTrack` 写完后等播放头追上已写入帧数再释放，
避免 `write()` 只入缓冲区就 `stop()` 导致的「播到一半断掉」。

失败信息（HTTP 码、火山返回码与 message）原样回显在设置界面，便于区分鉴权、音色、协议三类问题。

### 11.5 首次使用

1. 装桌面 APK（按 ABI 选对应 split）。
2. 装语音 APK（同样按 ABI）。
3. 桌面 → 设置 → 语音助手 → 启用（首次会拉起语音 App 的麦克风授权）。
4. 语音 App 里调整：引擎（本地/火山）、音色、语速、唤醒灵敏度、连续对话、云端对话。
