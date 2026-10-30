# UNI 语音模块 全逻辑说明

> 适用版本：voice APK 56.3 MB（arm64）、桌面 13.2 MB
> 最后更新：本文件随代码演进，改动语音链路时同步更新

---

## 一、总体结构

语音拆成独立 APK（`xyz.i4o.uni.voice`），桌面（`xyz.i4o.uni.launcher`）只保留总开关与状态显示。两者通过**带签名权限的跨进程广播**通信。

```
┌──────────────── 桌面 APK（launcher）────────────────┐
│ 语音总开关 / 状态点 / 对话记录（只读展示）            │
│ LauncherRuntime ← 执行车控动作（空调/媒体/导航/应用）  │
│ NavigationApps（导航 scheme + 地理编码）              │
└───────────────▲──────────────────────┬──────────────┘
                │ 有序广播              │ 有序广播
                │ VOICE_EXEC            │ VOICE_STATE
                │ VOICE_MEDIA_QUERY     │ VOICE_STATUS_QUERY
                │ VOICE_CONTROL         │
┌───────────────┴──────────────────────▼──────────────┐
│              语音 APK（voice，前台服务）              │
│  VoiceAssistService（1418 行，状态机 + 编排）          │
│  SherpaVoiceEngine（KWS / VAD / ASR / 播放）          │
│  CloudLlm（闲聊 + 地名纠错）                          │
│  VoiceTts → VolcanoWsTts（火山 WS）/ SystemTts（兜底） │
│  VoiceCommand（本地指令解析）                          │
└──────────────────────────────────────────────────────┘
```

权限：`xyz.i4o.uni.launcher.permission.VOICE` / `xyz.i4o.uni.voice.permission.VOICE`（signature 级，adb 无法伪造）

---

## 二、音频通道

| 项 | 值 |
|---|---|
| 采样率 | 16000 Hz |
| 帧长 | 320 samples = 20 ms |
| 来源 | `MediaRecorder.AudioSource.VOICE_RECOGNITION`（车机麦克风） |
| 播放 | `AudioTrack`，24 kHz（火山输出）或 16 kHz（自检回放） |
| 预录缓冲 | 1 s 环形（`preroll`），唤醒/开口瞬间补喂，防丢首字 |

---

## 三、状态机

```
         ┌──────────────────────────────┐
         │            IDLE              │ 常驻 KWS，等唤醒词
         └───────────┬──────────────────┘
   唤醒词命中 / 方控语音键 / 桌面按钮
                     ▼
         ┌──────────────────────────────┐
         │         LISTENING            │ 播唤醒应答（可选）+ 收音频
         └───────────┬──────────────────┘
      说完了(静音500ms/端点/超时)      VAD 判无语音过久
                     ▼                    │
         ┌──────────────────────────────┐ │
         │          THINKING            │──┘ 回 IDLE
         └───────────┬──────────────────┘
       本地规则命中？  云端返回？
                     ▼
         ┌──────────────────────────────┐
         │          SPEAKING            │ 播报（流式，边收边播）
         └───────────┬──────────────────┘
        播完 & 连续对话开 → 回 LISTENING（不重播应答）
        播完 & 连续对话关 → 回 IDLE
        命中「退下」 → 立刻回 IDLE
```

超时保护：

| 超时 | 值 | 作用 |
|---|---|---|
| `LISTEN_TIMEOUT_MS` | 8 s | 首轮聆听上限 |
| `FOLLOWUP_TIMEOUT_MS` | 6 s | 连续对话无语音自动退下 |
| THINKING watchdog | 15 s | 云端卡死则兜底播报 |
| SPEAKING watchdog | 25 s | 合成卡死则强制回 IDLE |

---

## 四、一次完整交互的时序

```
① 唤醒
   KWS 命中（pinyin token 表 + zipformer 3M）
     → beginListening(source="wakeword")
     → 播唤醒应答（火山预合成 PCM，磁盘缓存命中则零延迟）
     → 应答期间麦克风仍在采集（无 AEC，靠文本层过滤回声）

② 聆听
   每 20ms 一帧：
     VAD(silero) 判语音 → 门控后喂 ASR（含 400ms 句首补偿 + 600ms 尾巴）
     静音累计 500ms  /  模型端点  → 收句
     识别文本累计 < 160ms → 当噪声丢弃，继续听

③ 识别
   本地 CTC（25 MB zipformer2-ctc）
   或云端 sauc（开关控制，二选一，见第八节）

④ 过滤（文本层六道门）
   清占位符(<unk>/[unk]) → 剥唤醒词 → 长度≥2 → 非纯语气词
   → 非自己应答回声 → 置信度≥0.55

⑤ 解析
   VoiceCommand.parseAll：
     先去标点、补同音字（推下→退下、空条→空调、风凉→风量）
     多指令按「然后/再/，/、/并且/顺便/和」切分
     本地规则：空调/温度/风量/座椅/媒体/音量/静音/应用/导航/时间/退下
   命中 → 直接执行（不联网）

⑥ 执行
   本地动作 → RemoteBridge 发 VOICE_EXEC 给桌面
   桌面 LauncherRuntime 落地：调系统 API 或启动 App
   导航：NavGeocoder 地理编码 → WGS84→GCJ02 → androidauto://route

⑦ 播报
   短指令 → 预合成缓存（"好" / "搞定了"）直接播
   长回答 → 火山 WS 双向流式，按标点切句边合成边播
   火山不可用 → 系统 TTS 兜底

⑧ 收尾
   连续对话开 → 6 s 内可继续说（不重播应答）
   「退下/退出/闭嘴」→ 立即回 IDLE
```

---

## 五、唤醒（KWS）

| 项 | 说明 |
|---|---|
| 模型 | `models/kws/`（zipformer transducer 3M + `tokens.txt`） |
| 唤醒词 | 拼音 token 表 `assets/wake_pinyin.txt`，支持任意中文（自动转拼音） |
| 多唤醒词 | `settings.wakePhrases()`，默认「你好小U」 |
| 校验 | 设置页「自检」：火山合成唤醒词 → 重采样 16k → 喂 KWS 看是否命中 |
| 灵敏度 | 低 0.62 / 中 0.50 / 高 0.42（同时驱动 VAD 阈值） |

识别结果会先做**唤醒词剥离**：`你好小U/小U小U/嗨小U/小优/小尤/小游`（前 4 字内模糊匹配），剥完只剩语气词则视为“只是叫了一声”。

---

## 六、VAD 与识别门控

| 参数 | 值 | 说明 |
|---|---|---|
| 阈值 | 0.42 / 0.50 / 0.62 | 由灵敏度决定 |
| `minSilenceDuration` | 0.50 s | 静音多久算一句说完（社区常用 500~700ms） |
| `minSpeechDuration` | 0.20 s | 多长才算说话，滤咳嗽/咔哒 |
| `maxSpeechDuration` | 20 s | 单句上限 |
| 门控尾巴 | 30 帧 = 600 ms | 句尾不被切 |
| 句首补偿 | 20 帧 = 400 ms 环形缓冲 | speech 起点回补，"导"字不丢 |

**门控的意义**：不把静音喂给识别器。这是“静音被解成文字（你小优在）”的根治手段。

---

## 七、本地指令（离线可用）

`VoiceCommand` 全部是**规则匹配，零网络**：

| 类别 | 例 |
|---|---|
| 空调 | 开空调 / 24度 / 风量三档 / 内循环 |
| 座椅 | 座椅加热 / 座椅通风 |
| 媒体 | 下一首 / 上一首 / 暂停 / 播放 |
| 音量 | 大声点 / 静音 / 音量 30 |
| 应用 | 打开地图 / 回桌面 |
| 导航 | 导航到 XX（`navigate-to`） |
| 时间 | 几点了 / 今天几号 |
| 退出 | 退下 / 退出 / 闭嘴 / 别说了（含尾巴语气词） |

执行结果回复统一为短句：**好 / 搞定了 / 还不行**，并**预合成缓存到磁盘**（`AckCache`，键 = 引擎+音色+语速+指令+文本）。

---

## 八、云端识别（火山 sauc）

| 项 | 值 |
|---|---|
| URL | `wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async` |
| 鉴权 | `X-Api-Key`（API Key，新控制台一把）+ `X-Api-Resource-Id` + `X-Api-Request-Id` |
| 资源 ID | 默认 `volc.seedasr.sauc.duration`（豆包 2.0 小时版）；1.0 = `volc.bigasr.sauc.duration` |
| 请求参数 | `enable_nonstream=true`（二遍识别）、`show_utterances=true`（拿 definite）、`enable_ddc=true`、`end_window_size=800`、`force_to_speech_time=1000` |
| 上行 | 1 次 JSON 配置 + N 帧 16k/16bit/mono PCM（v3 二进制帧，与 TTS 同协议） |
| 下行 | `payload_msg.result`，`definite` 在 `utterances[last]` |

**当前是二选一**：开关打开则旁路本地识别器。目标是改成“并行 + 本地优先命中”（见第十一节）。

---

## 九、对话与播报

### LLM（闲聊）

| 项 | 说明 |
|---|---|
| 协议 | OpenAI 兼容 SSE `/chat/completions`，`reasoning_effort:"none"` |
| 输出约定 | `<e>情绪</e><c>语气细节</c>正文`（闲聊）；车控走本地，不调 LLM |
| 上下文 | 最近 4 轮（`MAX_HISTORY=8` 条消息） |
| 地名纠错 | `fixPlaceName()`：`navigate-to` 前把同音错字改写成标准地名（few-shot 5 例） |
| 人设 | `VoicePersona` 按当前火山音色的描述/场景自动生成，不做人工设定 |

### TTS（合成）

```
火山 WS 双向流式（首选）
  ├─ 音色 / 情绪 / 情感强度 / 音高 全部来自设置
  ├─ 按标点切句，多句并行发送，边收边播
  └─ 失败或未配置
        ↓
     系统 TTS（车机自带，保证有声；日志：system tts fallback）
```

唤醒应答与固定回复语**预合成并落盘缓存**（`AckCache`），第二次起零延迟、不耗额度。

---

## 十、文件职责

| 文件 | 行数 | 职责 |
|---|---|---|
| `VoiceAssistService` | 1418 | 前台服务、状态机、音频循环、过滤、编排 |
| `VoiceSettingsActivity` | 1035 | 双栏设置页（开关/对话记录/音色/凭据/自检） |
| `VolcanoWsTts` | 702 | 火山双向流式 TTS（v3 二进制帧） |
| `SherpaVoiceEngine` | 514 | KWS/VAD/ASR/播放，VAD 门控，云识别旁路 |
| `CloudLlm` | 411 | SSE 流式、标签解析、地名纠错、人设拼装 |
| `VoiceCommand` | 244 | 本地指令解析、同音字修正、多指令切分 |
| `VolcanoStreamAsr` | 241 | 火山 sauc 流式识别客户端 |
| `LanConfigServer` | 245 | 手机扫码配置（局域网） |
| `VoiceSettings` | 225 | 全部配置项读写 |
| `VolcanoCatalog` | 127 | 466 个火山音色元数据 |
| `VoiceModels` | 102 | 核心模型（asr/kws/vad）复制，音色按需复制 |
| `AckCache` | 92 | 预合成音频磁盘缓存 |
| `NavGeocoder`(桌面) | — | 天地图 `v2/search` 地理编码 + WGS84→GCJ02 |

---

## 十一、已知问题与待办

| 项 | 状态 |
|---|---|
| 无 AEC（回声消除） | 靠“应答期间文本过滤 + 长度门槛”糊；彻底解法需参考信号消除 |
| 云识别二选一 | 待改成并行：本地先命中车控就执行，未命中再等云端 |
| onnxruntime 未裁剪 | `libonnxruntime.so` 20.7 MB，minimal build 可降到 7~9 MB |
| KWS 模型 8.4 MB | 有 2 MB 小模型，但自定义唤醒词支持不确定 |
| 唤醒灵敏度只驱动 VAD | 未影响 KWS 自身阈值 |
| 火山额度保护 | 未做“每日上传秒数上限”熔断 |
| `.so` 未压缩存储 | APK 大 10 MB，换取安装后省 30 MB（当前选择） |

---

## 十二、关键日志速查

| 日志 | 含义 |
|---|---|
| `wake ack: 在呢` | 唤醒应答已播 |
| `asr=` | 原始识别结果（含 `<unk>` 占位符） |
| `wake word stripped: "你好小U你在干什么" -> "你在干什么"` | 唤醒词剥离 |
| `too short, ignored: "好小"` | 被长度门槛拦下 |
| `UniVoice.Asr: asr ws open, resource=…` | 云识别握手成功 |
| `tianditu 临泉县人民政府 -> 33.0415,115.2576` | 地理编码命中 |
| `route ok via … -> androidauto://route?…` | 导航 scheme 命中 |
| `speak via 火山 · 双向流式` | TTS 走的火山 |
| `system tts fallback: …` | 火山不可用，退系统 TTS |
| `geocode(cache) …` | 坐标缓存命中 |
| `vad threshold=0.5 (sens=2)` | 灵敏度与阈值 |
