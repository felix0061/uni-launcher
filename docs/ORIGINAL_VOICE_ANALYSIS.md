# 原车语音助手（小卡）拆解 & AEC 与主副驾识别机制

> 材料来源（全部本地可复现）：
> - `car-reports/xiaoka/com.ecarx.xiaoka.apk`（25.6 MB，`/system/app/AIXiaokaGUI/`）
> - `car-reports/vr-data/mnt/product/vr/vr/`（181 MB VR 资源，`/mnt/product/vr`）
> - `car-reports/config/vendor-etc/`（`/vendor/etc` 音频配置）
> - `car-reports/dumps/`（`audio_flinger`、`getprop` 等现场快照）
> 车机：领克 05 / IP753 / Android 9 / MSM8996（WCD9335 codec）

---

## 一、这台车的 AEC 到底是什么

### 1.1 AEC 是什么（概念）

AEC = Acoustic Echo Cancellation，**声学回声消除**。

问题场景：喇叭在放声音（音乐 / 语音播报 / 导航提示），麦克风同时开着。麦克风会录到自己的喇叭声——这就是"回声"。如果不处理：

- 语音识别会把自己的播报当成用户说话 → 自问自答
- 免提通话对方会听到自己的回声
- 唤醒词会被自己的声音误触发

AEC 的原理：**已知播放信号（参考信号），从麦克风信号里把它的"回声成分"减掉**。

```
喇叭信号 x(t) ──▶ 声学路径 h(t) ──▶ 麦克风收到 y(t) = 回声 + 人声 + 噪声
                                        │
                    AEC: 用 x(t) 估计 h(t)，算出 ẑ(t) ≈ 回声，再做 y(t) - ẑ(t)
                                        ▼
                                   只剩人声 + 噪声
```

工程上要满足两个条件才能真正消干净：

| 条件 | 说明 | 本车情况 |
|---|---|---|
| **参考信号必须精确** | 要拿到"正准备播"的数字信号（不是录回来的） | 原厂语音自己能拿到（见 §2.3） |
| **延时必须稳定且已知** | 参考与麦克风之间差几十~几百毫秒，AEC 要跟踪 | 平台方案能，第三方 App 不能 |

### 1.2 本车实现：Qualcomm Fluence（平台级）

`/vendor/etc/audio_effects.xml` 里的证据：

```xml
<library name="audio_pre_processing" path="libqcomvoiceprocessing.so"/>
<effect name="aec" library="audio_pre_processing" uuid="0f8d0d2a-59e5-45fe-b6e4-248c8a799109"/>
<effect name="ns"  library="audio_pre_processing" uuid="1d97bb0b-9e2f-4403-9ae3-58c2554306f8"/>
```

`dumpsys media.audio_flinger` 也能看到实时挂载：

```
Acoustic Echo Canceler / Qualcomm Fluence
```

属性开关（`getprop`）：

```
persist.audio.fluence.voicecall = true    ← 通话时启用
persist.audio.fluence.speaker  = true     ← 免提（外放）时启用
persist.audio.fluence.voicerec = false    ← 普通录音不启用
```

**这说明：**

1. AEC 跑在 **ADSP** 上，由 WCD9335 codec + Fluence 算法完成，不占 CPU
2. 它只在**通话 / 免提**场景自动生效（`voicecall` / `speaker` 为 true）
3. 普通 `AudioRecord` 录音（`voicerec=false`）**默认没有 AEC**

### 1.3 为什么我们自己开 AEC 反而把麦克风搞哑了

我们试过用 Android 的 `AcousticEchoCanceler` API 给 `AudioRecord` 挂 AEC：

```java
AcousticEchoCanceler aec = AcousticEchoCanceler.create(audioSessionId);
aec.setEnabled(true);   // 日志：aec enabled
```

实测结果（同一段怠速环境）：

| AEC | 麦克风电平 |
|---|---|
| 开 | `mic rms = 0~5`（几乎静音） |
| 关 | `mic rms = 108` |

原因：**Fluence 是"通话场景"调好的**，它假设：

- 输入来自 `VOICE_COMMUNICATION` 源（通话麦路径）
- 有平台侧提供的参考信号
- 有对应的 AGC/NS 配置

我们用普通录音源强行挂上它，它把整条链路的增益按"通话"参数重算，结果是既没有参考信号可减，又把增益压死。

> 结论：**第三方 App 不要自己挂平台 AEC**。要做回声抑制，应该自己做（见 §4），或者用 `VOICE_COMMUNICATION` 源让平台自己处理。

### 1.4 原厂语音用的是它自己的 AEC

`audioconfig.json` 里有个模块叫 **`PromptSyncedInput`**（简称 `psi`）：

```json
{
    "type": "PromptSyncedInput",
    "name": "psi",
    "sink_names":   ["mic_in", "spk_in"],
    "source_names": ["mic_out", "spk_out"],
    "buffer_time": 1500
}
```

注意 `sink_names` 同时有 **`mic_in`（麦克风）和 `spk_in`（播放）**，`buffer_time = 1500ms`。

这就是：**把"正在播放的提示音/TTS"作为参考信号，与麦克风对齐 1.5 秒窗口，自己做回声消除**。

也就是说原厂有**两套 AEC**：
- 平台 Fluence（通话/免提兜底）
- 自家 `PromptSyncedInput`（对自己播报做精确消除，1.5s 缓冲对齐）

关掉小卡后，我们 App 没有这层能力——**这就是"播报中自己开口会被打断/或播报被自己的声音干扰"的根源之一**。

---

## 二、小卡的完整架构（拆解结果）

### 2.1 引擎：Nuance Dragon Drive + 自研前端

`ddfw/config/dcy11/natp.cfg` 里列出了运行的服务名：

```
SAM.ChannelNames = HostAgent, MonitorService, DragonDriveCommonService,
                   DragonDrivePrompterService, DragonDriveAsrService,
                   DragonDriveBiometryService, SASService, FileService,
                   ExportService, SDDEMService, ShutdownService, AliveService, GDM
```

| 服务 | 作用 |
|---|---|
| `DragonDriveAsrService` | **Nuance 云端/本地 ASR** |
| `DragonDrivePrompterService` | 播报（TTS 提示音） |
| **`DragonDriveBiometryService`** | **声纹识别（Biometry）** |
| `SDDEMService` | 对话管理（Dialog Manager） |
| `SASService` | 音频前端控制（Signal Analysis Service） |

`libvrService.so` 里还出现 `nuance`（4 处）、`Nuance`（9 处）——确认是 Nuance 的引擎。

### 2.2 本地模型（`/mnt/product/vr/vr/`）

| 文件 | 大小 | 作用 |
|---|---|---|
| `china_corepoi.pcf` | **144 MB** | 离线 POI 库（本地找地点，不用联网） |
| `type.model.Enc` | 24.7 MB | 意图分类模型 |
| `slm_cloud.pcf` | 9.5 MB | 云端语言模型 |
| **`wuw_model.dat`** | **6.2 MB** | **唤醒词模型（本地 KWS）** |
| `model.dat` | 6.2 MB | 主 NLU 模型 |
| `slot.model.Enc` | 3.5 MB | 槽位抽取模型 |
| `Car_2_train_data.model` | 3.2 MB | 车控（Car）NLU 训练数据 |
| `App_train_data.model` | 2.5 MB | 应用控制 NLU |
| `ddfw/biometry/NSIDData/helloJili_Calibration.dat` | 93 KB | **声纹引擎标定数据** |
| `ddfw/biometry/NSIDData/NVSLEngine_demo.xml` | 5 KB | Nuance 声纹引擎（NSID）配置 |

**注意 `wuw_model.dat` 和 `china_corepoi.pcf` 这两点：**
- 唤醒是**纯本地**的（6.2MB 模型常驻内存，断网也能唤醒）
- 找地点也是本地 POI 优先（144MB，覆盖全国核心 POI）

### 2.3 音频前端管道（`audioconfig.json`）

配置文件顶层结构：

```json
{ "version": "AudioMgr 1.0", "audio_scenario": [...], "module_config": [...], "audio_format": {...} }
```

**输入格式（最关键的一行）：**

```json
{
    "type": "AudioInput",
    "name": "SDS_mic",
    "adapter_type": "PAL_BUFFER_AUDIO",
    "audio_format": { "uses": "16khz_7ch" },     ← 7 通道 / 16kHz
    "adapter_params": { "device_name": "default", "buffer_count": 50 },
    "interleaved_format": "true"
}
```

**它一次性抓 7 个通道的麦克风数据。**

管道（以唤醒+识别为例）：

```
SDS_mic (7ch)
   ├─▶ psi (PromptSyncedInput: mic + 播放参考，1.5s 对齐)   ← AEC
   ├─▶ asd_p_7ch / asd_p_bi / asd_p_2ch (流分发，按需要选通道)
   ├─▶ SpeechSignalEnhancement (SSE)                        ← 语音增强/波束
   ├─▶ AudioSignalAnalysis                                  ← 信号分析
   ├─▶ WUW_SSE (wuw_model.dat)                              ← 唤醒
   └─▶ SDS_asr (DragonDriveAsrService)                       ← 识别
         └─▶ biometry (NSID)                                 ← 声纹
```

模块类型清单（从配置里去重得到）：

| type | 作用 |
|---|---|
| `AudioInput` | 采集（16kHz × 7ch） |
| `PromptSyncedInput` | 播放与麦克风对齐（AEC 参考） |
| `AudioStreamDistributor` | 通道路由（1 / 4 / 7 通道） |
| `SpeechSignalEnhancement` | 语音增强（降噪 / 波束） |
| `AudioSignalAnalysis` | 信号分析（能量/信噪比/方位） |
| `SampleRateConverter` | 重采样 |
| `AudioOutput` | 输出 |

**通道数声明里同时出现 1 / 4 / 7** —— 说明它按场景切换：唤醒用 7 通道全阵列，识别时可能用 1 通道（已增强的单路）。

---

## 三、主副驾识别是怎么做的

### 3.1 结论：**7 麦阵列的方位估计（DOA）+ 声纹（Biometry）双保险**

不是"靠说话内容猜"，也不是简单按"谁在说话"分配。

证据链：

**① 7 通道阵列输入**

```
"audio_format": { "uses": "16khz_7ch" }
```

7 个通道 = 多个麦克风的空间分布。有了多通道，才能算**通道间时延差（TDOA）**，进而得到**声源方位角（DOA）**。

典型布局（车顶/顶棚阵列）：
```
     前
  M1 ──── M2        主驾侧 ←→ 副驾侧
  │        │
  M3 ──── M4        第二排
  │        │
  M5      M6        第三排 / 后备
     M7 = 参考/回采通道（或低音炮回采）
```

**② `AudioSignalAnalysis` 模块**

配置里专门有这个模块，作用是从多通道算出信号级信息（能量、信噪比、方位）。DOA 就在这一层或 `SSE` 里算。

**③ `DragonDriveBiometryService` + NSID 声纹模型**

```
ddfw/biometry/NSIDData/helloJili_Calibration.dat   93 KB
ddfw/biometry/NSIDData/NVSLEngine_demo.xml          5 KB
```

`NSID` = Nuance Speaker Identification。**声纹 = 谁在说话**。
`helloJili_Calibration.dat` 是"你好吉利"唤醒词的声纹标定数据。

**④ 场景配置里有专门的 biometry 管道**

```json
{
  "name": "audioscenario_asr_biometry",
  "audiopaths": [
      ["SDS_mic",        "asd_p_bi"],
      ["asd_p_bi:out_three", "Speech_SSE"],
      ["Speech_SSE",     "SDS_asr"],
      ["SDS_asr",        "biometry"]        ← 识别结果送声纹
  ]
}
```

### 3.2 实际判定流程（推断，但证据充分）

```
用户说「打开车窗」
   │
   ├─ 7 通道麦克风 → TDOA 估计 → 方位角 θ
   │     θ 落在主驾扇区 → 判定「主驾在说话」
   │     θ 落在副驾扇区 → 判定「副驾在说话」
   │
   ├─ 同时：声纹比对（NSID）
   │     与已注册声纹匹配 → 知道是「车主张三」还是「乘客」
   │
   └─ 两者结合 → 决定「开哪扇窗」
        主驾说「打开车窗」→ 左前窗
        副驾说「打开车窗」→ 右前窗
```

这解释了一个现象：**在小卡上，主驾和副驾说同一句"打开车窗"，开的是不同的窗**。命令词相同，靠**谁在说**来消歧。

而我们从 `libvrService.so` 里挖到的命令文本也印证了这点（它们是"显式指定座位"的版本）：

```
打开主驾车窗 / 打开副驾车窗
打开主驾座椅加热 / 打开副驾座椅通风
调节到主驾驶有声音 / 调节到副驾驶有声音 / 调节到后排有声音
```

后三条 `调节到 X 有声音` 是**音区（Sound Zone）测试指令** —— 说明这套系统还支持"只让某个座位的喇叭出声"，这需要按音区分区的功放通道，也是 7 通道阵列体系的一部分。

### 3.3 关键差别：**这套能力我们拿不到**

| 需要 | 原厂有 | 我们 |
|---|---|---|
| 7 通道麦克风原始数据 | ✅ `16khz_7ch` | ❌ HAL 只暴露 2 个逻辑输入设备（`Built-In Mic` / `Back Mic`），且 App 侧多为单声道 |
| 麦克风阵列几何（间距/朝向） | ✅ 标定在算法里 | ❌ 未知 |
| DOA 算法 | ✅ SSE / AudioSignalAnalysis | ❌ 需自己写 + 需要几何 |
| 声纹模型与注册数据 | ✅ NSID + Calibration | ❌ 无模型、无注册流程 |
| 音区输出路由 | ✅ 分区功放 | ❌ 只有一条 `speaker` 总线 |

我们可以做的（已经在做的）只有**双麦延迟求和**：拿两路（如果 HAL 真给两路）做相干增强，提升信噪比 —— 这是 §3.1 里最粗糙的一档，跟 7 通道 DOA + 声纹完全不是一个量级。

---

## 四、这套架构给我们项目的直接启示

### 4.1 唤醒词

| 项 | 原厂 | 我们 |
|---|---|---|
| 模型 | `wuw_model.dat` 6.2 MB（自研/Nuance） | sherpa-onnx KWS zipformer 3.3M（8.4 MB） |
| 运行 | 本地常驻 | 本地常驻 |
| 通道 | 7ch 阵列（波束后再喂） | 1~2ch |

**我们的唤醒率不如原厂，很大一部分不在模型，而在"喂给模型的是单麦原始信号"**，原厂喂的是 7 通道波束增强后的信号。

### 4.2 AEC

原厂的 `PromptSyncedInput` 给了明确思路：**用自己的播报信号当参考，1.5s 缓冲对齐**。
我们现在的对策是"播报时避开检测 + 打断判定用自适应基线"，属于绕过而不是解决。
如果以后要做，正确做法是：

```
我们播出的 PCM（已知） → 延迟估计 → 建回声模型 → 从麦克风里减掉
```
这不需要 DSP，纯软件可行（我们播的是自己生成的音频，参考信号完全可控）。

### 4.3 音区

`调节到副驾驶有声音` 说明功放是**分区**的。如果 ECARX 车控 API 能按音区调音量，我们也能做"只让主驾喇叭播报"。这条待验证（`CAR_VENDOR_EXTENSION` 我们现在有了）。

---

## 五、一句话总结

| 问题 | 答案 |
|---|---|
| **AEC 是什么** | 用"已知的播放信号"把麦克风里的回声减掉；本车是 Qualcomm Fluence（ADSP 上跑，仅通话/免提自动生效）；第三方 App 强开会把麦压哑（实测 rms 108→0~5） |
| **原厂语音是什么** | Nuance Dragon Drive（ASR/播报/声纹）+ 自研 7 通道音频前端 + 本地唤醒模型 6.2MB + 本地 POI 144MB |
| **主副驾怎么识别** | **7 麦阵列 TDOA→方位角（DOA）** 判定说话人在主/副驾扇区，**声纹（NSID）** 确认是谁；两者结合决定"开哪个窗" |
| **我们能复刻吗** | 只能做双麦延迟求和（相干增强 ~3dB）；7 通道原始数据、阵列几何、DOA 算法、声纹模型都拿不到 |
