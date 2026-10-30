# 顶替小卡（com.ecarx.xiaoka）方案评估

> 依据：小卡 APK 清单反编译、`ecarxinteractiveservice` 反汇编、
> `/mnt/product/vr` 资源、`audioconfig.json`、以及我们已有的实测（平台签名 / system UID / 方控广播）。

---

## 一、为什么可行（技术前提全部满足）

| 条件 | 小卡 | 我们 | 结论 |
|---|---|---|---|
| 包名 | `com.ecarx.xiaoka` | 改成同名 | — |
| 签名 | 平台证书 `c8a2e9bc…` | **同一张证书**（已验证） | ✅ |
| sharedUserId | `android.uid.system` | 已是 | ✅ |
| versionCode | 986 | 设 990+ | ✅ |
| 安装位置 | `/system/app/AIXiaokaGUI` | `/data/app` 覆盖 | Android 标准机制 |

`/data/app` 同名包覆盖系统应用的条件只有两个：**签名一致 + versionCode 不降低**。这两条我们都满足。

**回滚成本极低**：`adb uninstall com.ecarx.xiaoka` → `/data` 那份消失，系统分区那份自动回归。

---

## 二、能吃的红利（按价值排序）

### 红利 1：厂商 VR 引擎的客户端身份 ★★★★★

小卡清单里这个组件是关键：

```
com.ecarx.speech.VRClientService
```

它说明小卡**只是厂商引擎的客户端**。真正的能力在引擎侧（`libvrService.so` / Dragon Drive 守护进程）：

| 能力 | 现状（我们） | 顶替后（可能拿到） |
|---|---|---|
| 麦克风 | 1~2 通道，HAL 限流 | **16kHz × 7 通道阵列** |
| 语音前端 | 无（自己写双麦延迟求和） | SSE（波束 + 降噪）+ PromptSyncedInput（AEC） |
| 唤醒 | sherpa-onnx KWS zipformer | 原厂 `wuw_model.dat`（6.2MB，已在车机上） |
| 识别 | 火山云端 sauc | Nuance Dragon Drive ASR（本地 + 云端） |
| 主副驾识别 | 无 | DOA 方位 + 声纹（NSID） |
| 离线找地点 | 无（靠高德） | `china_corepoi.pcf` 144MB 本地库 |

**这一条如果打通，等于把"自研玩具"换成"原厂引擎"**，前面所有关于唤醒率、截断、AEC 的困扰会大幅缓解。

> 前提：引擎按包名鉴权。我们只在 `libgkai-api.so` 里找到 `com.ecarx.xiaoka.base.protobuf`（JNI 类名），没找到显式鉴权逻辑——**需要实测**。

### 红利 2：privapp 权限继承 ★★★★☆

小卡声明的权限（装在 `/data` 用平台签名后，`signature` 级别的照样满足）：

```
android.car.permission.CAR_VENDOR_EXTENSION          ← 车控
android.car.permission.CONTROL_CAR_CLIMATE           ← 空调
android.car.permission.CAR_CONTROL_AUDIO_VOLUME      ← 音频总控（我们现在缺这个）
android.cevt.dimsupportservice.permission.DIM_MESSAGING
android.permission.MOUNT_UNMOUNT_FILESYSTEMS
```

**`CAR_CONTROL_AUDIO_VOLUME` 尤其值钱**：有了它，音量控制不必再走 ECARX 的 `setVolumeInfo` 字符串接口，可以直接操作各条音频总线（含导航、TTS、媒体），音区控制也有戏。

### 红利 3：系统入口全归我们 ★★★★☆

小卡清单里监听的动作，顶替后全部由我们接：

```
ecarx.intent.action.ECARX_KEY_RVOICEASSIST_EVENT   方控语音键（我们现在靠 ENTER 广播，已可用）
ecarx.intent.action.ECARX_KEY_EVENT_RVOICE_EVENT   语音键变体
ecarx.intent.action.ECARX_KEY_RCALL_EVENT          电话键
ecarx.intent.action.ECARX_KEY_RSRC_EVENT           资源/多媒体键
ecarx.intent.action.ECARX_TEXT_TO_NLU              ★ 其他 App 可直接喂文本给我们的 NLU
ecarx.intent.action.VOICE_SERVICE_STARTED          语音服务就绪
ecarx.action.ECARX_ACITON_HOME                     回桌面
com.ecarx.keep.DaemonService / KEEP_LIVING         保活
```

**`ECARX_TEXT_TO_NLU` 是个隐藏入口**：任何系统应用都可以把文本发给我们做语义解析——这意味着我们的 NLU 可以成为系统级服务（比如桌面搜索框、其他 App 的语音按钮都能调我们）。

### 红利 4：独占麦克风，彻底消除争抢 ★★★★☆

现状：小卡和我们同时想开麦克风，必须禁掉小卡才行（我们之前就是这么做的）。
顶替后：**同一个包只有一个语音实现**，不存在争抢，也不用再 `pm disable`。

### 红利 5：音区（Sound Zone）控制 ★★★☆☆

小卡的命令表里有：

```
调节到主驾驶有声音 / 调节到副驾驶有声音 / 调节到后排有声音
```

说明功放是按座位分区的。配合 `CAR_CONTROL_AUDIO_VOLUME`，可以做到：

- 只让主驾喇叭播报（副驾睡觉时不吵他）
- 导航播报只走主驾，音乐保持全车

### 红利 6：原厂唤醒词可用 ★★★☆☆

如果引擎客户端打通，"你好领克"这类原厂唤醒词直接可用，用户习惯不用改（我们现在的"你好小优"要重新培养）。

### 红利 7：保活机制 ★★☆☆☆

小卡有 `com.ecarx.keep.DaemonService` + `KEEP_LIVING` 广播，这是厂商的保活通道。顶替后可以复用，语音服务不容易被系统杀掉。

---

## 三、必须改的东西

| # | 改动 | 说明 | 工作量 |
|---|---|---|---|
| 1 | 包名改 `com.ecarx.xiaoka` | `applicationId` + 所有 `xyz.i4o.uni.voice` 引用 | 小 |
| 2 | versionCode > 986 | 否则装不上 | 极小 |
| 3 | **补同名组件** | 其他 App 可能直接启动 `XKMainActivity` / `XKApplication`，需提供同名类做转发（否则那些入口会崩） | 中 |
| 4 | 数据迁移 | 新包名 = 新数据目录，用已有的「导出/导入设置」 | 小 |
| 5 | 桌面联动 | 我们 launcher 里对"原车助手"的判断要改（现在会探测小卡是否存在） | 小 |
| 6 | 先 `pm enable` 小卡 | 之前被我们 `disable-user` 了 | 极小 |
| 7 | 移除 push/统计 SDK 依赖 | 小卡清单里有 `com.ecarx.push` / `com.ecarx.statistic` 的 BuildInfo，我们不需要，但**不能声明同名 class 冲突** | 小 |

---

## 四、风险（必须知道）

| 风险 | 说明 | 缓解 |
|---|---|---|
| **privapp 白名单** | Android 的 privileged 白名单只认 `/system` 分区；`/data` 覆盖包在部分实现上拿不到 privileged 权限 | 我们走 signature 路线，多数权限仍满足；实测确认 |
| **引擎鉴权未知** | 厂商引擎可能校验包名 + 签名 + 内部 token | 阶段 0 先试 bind，失败就当没这条红利 |
| **系统完整性校验** | 部分车机启动时校验 system 应用哈希 | 概率低（test-keys 机器一般不做）；异常可回滚 |
| **功能缺口** | 顶替后小卡 UI 没了；若系统某处硬编码它的 Activity 名，会报 ActivityNotFound | 补同名 Activity 做转发 |
| **"两个语音"** | 如果我们保留 `xyz.i4o.uni.voice` 又装一个 `com.ecarx.xiaoka`，等于两个语音服务 | 二选一，别并存 |

---

## 五、建议的实施顺序（分段可回滚）

### 阶段 0：不改包名，先验三条边界（半天）

| 试验 | 方法 | 决定什么 |
|---|---|---|
| ① 7 通道采集 | `AudioRecord` 传 channelMask `0x800000FF`（8ch）或 `0x8000003F`（6ch） | 若能拿到 ≥4 通道，**根本不用顶替** |
| ② 绑 `VRClientService` | `bindService(new Intent().setComponent("com.ecarx.xiaoka", "com.ecarx.speech.VRClientService"))` | 看厂商引擎是否只认这个包名 |
| ③ 试 `IInteractiveAPI` 的 `onKeyEvent` | 我们已有 `CAR_VENDOR_EXTENSION` | 方控键是否有结构化回调（比广播更可靠） |

**如果 ① 成功 → 直接做阵列处理，不改包名。**
**如果 ① 失败但 ② 成功 → 顶替价值极大，值得做。**

### 阶段 1：顶替但不接引擎（1 天）

- 改包名 + versionCode，装上去
- 验证：权限继承（`dumpsys package` 看 `CAR_CONTROL_AUDIO_VOLUME` 是否 granted）
- 验证：方控键、`ECARX_TEXT_TO_NLU`、保活广播是否都到我们
- **这一步就能拿到红利 2/3/4/7**

### 阶段 2：接引擎（不确定，需逆向）

- 逆向 `VRClientService` 的 AIDL 接口
- 实现客户端 → 拿 7ch 阵列 + 本地唤醒 + 本地 ASR
- **这一步拿到红利 1/5/6**

---

## 六、对我们项目的具体功能优化（可落地清单）

按"顶替后能做"排列：

| 功能 | 现在 | 顶替后 | 依赖阶段 |
|---|---|---|---|
| 唤醒率 | 单麦 + 小模型 | 7 麦波束 + 原厂模型 | 2 |
| 开会时说话被打断 | 靠自适应门限硬扛 | 前端 SSE 直接消回声 | 2 |
| 主副驾区分 | 无 | DOA + 声纹，开对侧窗 | 2 |
| 断网找地点 | 无 | 本地 144MB POI | 2 |
| 音量/音区精细控制 | 走 ECARX 字符串接口 | `CAR_CONTROL_AUDIO_VOLUME` 直控总线 | 1 |
| 系统级 NLU 入口 | 无 | `ECARX_TEXT_TO_NLU` | 1 |
| 语音服务保活 | START_STICKY | `KEEP_LIVING` 通道 | 1 |
| 电话/多媒体键联动 | 无 | `KEY_RCALL` / `KEY_RSRC` | 1 |
| 原厂唤醒词 | 不支持 | 若引擎可用则支持 | 2 |
| 与桌面/状态栏联动 | 靠我们自己的 launcher | 系统原生入口指向我们 | 1 |

---

## 七、一句话结论

**顶替小卡 = 拿到"身份"和"入口"，不一定拿到"引擎"。**

- 身份（权限、system UID、广播入口）→ **几乎确定能拿到**，阶段 1 就能兑现
- 引擎（7 麦阵列、原厂唤醒、本地 ASR/POI）→ **取决于厂商引擎是否按包名鉴权**，需要阶段 0 先验

所以正确顺序是：**先验阶段 0 的三条边界，再决定要不要动包名**——因为一旦动，语音入口在那段时间是坏的，虽然能回滚，但体验会断。
