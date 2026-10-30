# 领克 05 车机（ECARX XC 平台）车控接口文档

> 车机：领克 05，Android 9（API 28），SoC MSM8996
> 抓取时间：2026-10-30，ADB 地址 `192.168.22.197:5555`
> 所有内容来自车机自身二进制（框架 jar + 系统 APK），非猜测。

---

## 0. 一页速查

| 项 | 值 |
|---|---|
| **主接口 AIDL** | `com.ecarx.ecarxinteractiveapi.IInteractiveAPI` |
| **binder 服务名** | `ecarx_interactive` |
| **绑定 Action** | `android.intent.action.START_INTERACTIVE_SERVICE` |
| **绑定组件** | `com.ecarx.ecarxinteractiveservice/.InteractiveService`（`exported=true`） |
| **客户端封装类** | `com.ecarx.ecarxinteractiveapi.ECarXInteractiveManager` |
| **权限** | `android.car.permission.CAR_VENDOR_EXTENSION`（signature\|privileged） |
| **框架 jar（boot classpath，所有 App 可见）** | `/system/framework/ECarXInteractiveAPI.jar`<br>`/system/framework/ecarx.adapterapi.jar` |
| **可选客户端 SDK** | `/system/app/ECarXInteractiveService/jar/ecarxinteractivesdk.jar` |

**覆盖能力**：空调（开关/温度）、车窗/天窗（开/关/百分比）、音量（增减/静音/查询）、挡位/车速/方向盘转角、油量、GPS、传感器、日夜模式、倒车影像状态、麦克风抢占、导航焦点、方控语音键。

---

## 1. 三层接口关系

```
你的 App
   │
   ├─(推荐) ECarXInteractiveManager  ← /system/framework/ECarXInteractiveAPI.jar
   │        └─ IInteractiveAPI (AIDL) ──binder──▶ ECarXInteractiveService
   │
   ├─(备选) VehicleManager           ← ecarxinteractivesdk.jar
   │        └─ com.ecarx.xui.adaptapi.car.ICar ──▶ ecarx.adapterapi.jar
   │
   └─(标准) android.car.Car / CarPropertyManager / CarHvacManager
```

- **第一层**是 ECARX 自己的 IPC，能力最全（含语音/麦克风/导航焦点），本文件重点。
- **第二层**是进程内封装，直接操作适配层，需要 `IVehicleManager` 才能拿状态回调。
- **第三层**是 Android Automotive 标准 API，只能覆盖标准属性（HVAC/车窗），且受 `android.car.permission.CONTROL_CAR_*` 限制。

---

## 2. 绑定与权限

### 2.1 权限声明

```xml
<uses-permission android:name="android.car.permission.CAR_VENDOR_EXTENSION"/>
```

`ECarXInteractiveManager.checkCallPermission()` 会做校验，未授权时所有调用返回空/失败。
这是 **signature|privileged** 级别权限，普通第三方包**默认拿不到**。

### 2.2 绑定方式（框架 jar 已在 boot classpath，无需打包 AIDL）

```java
import com.ecarx.ecarxinteractiveapi.ECarXInteractiveManager;
import com.ecarx.ecarxinteractiveapi.ECarXInteractiveListener;

ECarXInteractiveManager mgr = new ECarXInteractiveManager(context);   // 构造即异/同步绑定
mgr.registerCarDataListener(listener);                               // 注册状态回调
int gear = mgr.getDrivingMode();
```

> 编译期需要把 `/system/framework/ECarXInteractiveAPI.jar` 加进 classpath
> （`compileOnly`，运行期由 boot classpath 提供，不打包进 APK）：
> ```gradle
> compileOnly files('libs/ECarXInteractiveAPI.jar')
> ```

### 2.3 手工绑定（不想依赖框架类时）

```java
Intent i = new Intent("android.intent.action.START_INTERACTIVE_SERVICE");
i.setComponent(new ComponentName("com.ecarx.ecarxinteractiveservice",
        "com.ecarx.ecarxinteractiveservice.InteractiveService"));
bindService(i, conn, Context.BIND_AUTO_CREATE);
// 在 onServiceConnected 里：
// IInteractiveAPI api = IInteractiveAPI.Stub.asInterface(service);
```

`ECarXInteractiveService.apk` 的清单里该 service **没有声明 `android:permission`**，
所以能否连上取决于 `checkCallPermission()`（应用层再校验一次）。

---

## 3. IInteractiveAPI 全量方法

| 方法 | 说明 |
|---|---|
| `int getDrivingMode()` | 挡位 + 驾驶模式，见 §3.1 `GEAR_*` |
| `String getAirConditionerInfo(int type)` | 读空调项，`type` 见 §3.3 `AC_*` |
| `boolean setAirConditionerInfo(String action, String value)` | 写空调，`action`=turnon/turnoff/settemp |
| `String getVolumeInfo(int type)` | 读音量项（§3.4） |
| `boolean setVolumeInfo(String action, String value)` | 写音量（setvolume/mute/unmute） |
| `String getWindowInfo(int type)` | 读车窗项（§3.2） |
| `boolean setWindowInfo(int type, String action, String value)` | 写车窗（open/close，百分比用 type=114） |
| `boolean isCarAbilitySupport(int module)` | 该模块是否被本车支持 |
| `boolean isControlSupport(int type)` | 该具体项是否可控 |
| `int getCarDataReportFreq(int type)` | 该项数据上报频率 |
| `boolean registerCarDataListener(IInteractiveCallback cb, String module)` | 订阅状态变化 |
| `boolean unRegisterCarDataListener(IInteractiveCallback cb, String module)` | 取消订阅 |
| `void hmiRequestUseMic()` / `void hmiReleaseMic()` | 抢占/释放麦克风（**和原车语音互斥的关键**） |
| `void requestNaviFocus(String pkg)` | 请求导航焦点（导航播报优先） |
| `boolean isDayMode()` | 当前是否日间模式 |
| `void setEnabledDisplayApp(String pkg)` / `boolean isEnabledDisplayApp(String pkg)` | 驾车禁用名单控制 |
| `boolean isReverseCameraOpened()` | 倒车影像是否打开 |
| `void onHMIActivityShowing(String pkg, boolean showing)` | 告知系统 HMI 是否在前台 |
| `void notifyPhoneConnectStatuschanged(String addr, int state)` | 蓝牙电话状态同步 |

### 3.1 挡位 / 驾驶信息

| 常量 | 值 |
|---|---|
| `GEAR_NEUTRAL` | 1 |
| `GEAR_REVERSE` | 2 |
| `GEAR_PARK` | 3 |
| `GEAR_DRIVE` | 4 |

| 条目 ID | 值 | 读法 |
|---|---|---|
| `VEHICLE_DRIVING_SPEED` | 11 | `getCarDataReportFreq(11)` / 回调上报 |
| `VEHICLE_DRIVING_GEAR` | 12 | 同上 |
| `VEHICLE_DRIVING_WHEEL` | 13 | 方向盘转角 |

### 3.2 车窗（`getWindowInfo` / `setWindowInfo` 的 type）

| 常量 | 值 | 含义 |
|---|---|---|
| `VEHICLE_WINDOW_SKYLIGHT_STATUS` | 109 | 天窗 |
| `VEHICLE_WINDOW_LEFT_FRONT_STATUS` | 110 | 左前 |
| `VEHICLE_WINDOW_LEFT_BACK_STATUS` | 111 | 左后 |
| `VEHICLE_WINDOW_RIGHT_FRONT_STATUS` | 112 | 右前 |
| `VEHICLE_WINDOW_RIGHT_BACK_STATUS` | 113 | 右后 |
| `VEHICLE_WINDOW_PERCENT_CONTROL` | 114 | 百分比控制 |
| `VEHICLE_WINDOW_FRONT_STATUS` | 115 | 前排（组合） |
| `VEHICLE_WINDOW_BACK_STATUS` | 116 | 后排（组合） |
| `VEHICLE_WINDOW_ALL_STATUS` | 117 | 全部 |

动作字符串：

| 常量 | 值 |
|---|---|
| `VEHICLE_WINDOW_OPEN_ACTION` / `..._OPEN_STATUS` | `"open"` |
| `VEHICLE_WINDOW_CLOSE_ACTION` / `..._COLSE_STATUS` | `"close"` |

### 3.3 空调

| 常量 | 值 | 说明 |
|---|---|---|
| `VEHICLE_MODULE_AIRCONDITIONER_CONTROL` | 5 | 模块 ID |
| `VEHICLE_AIRCONDITIONER_MAX_TEMP` | 105 | 最高温度 |
| `VEHICLE_AIRCONDITIONER_MIN_TEMP` | 106 | 最低温度 |
| `VEHICLE_AIRCONDITIONER_STATUS` | 107 | 开关状态 |
| `VEHICLE_AIRCONDITIONER_CURRENT_TEMP` | 108 | 当前设定温度 |
| `VEHICLE_AIRCONDITIONER_TURNON_ACTION` | `"turnon"` | 开 |
| `VEHICLE_AIRCONDITIONER_TURNOFF_ACTION` | `"turnoff"` | 关 |
| `VEHICLE_AIRCONDITIONER_SETTEMP_ACTION` | `"settemp"` | 温度值（字符串，如 `"22.5"`） |
| `VEHICLE_AIRCONDITIONER_OPEN_STATUS` | `"on"` | |
| `VEHICLE_AIRCONDITIONER_CLOSE_STATUS` | `"off"` | |
| `VEHICLE_CONTROL_RESULT_SUCCESS` / `..._FAIL` | `"success"` / `"fail"` | |

### 3.4 音量

| 常量 | 值 |
|---|---|
| `VEHICLE_VOLUME_MUTE` | 101 |
| `VEHICLE_VOLUME_MAX_VOLUME` | 102 |
| `VEHICLE_VOLUME_MIN_VOLUME` | 103 |
| `VEHICLE_VOLUME_CURRENT_VOLUME` | 104 |
| `VEHICLE_VOLUME_SETVOLUME_ACTION` | `"setvolume"` |
| `VEHICLE_VOLUME_MUTE_ACITON` / `..._STATUS` | `"mute"` |
| `VEHICLE_VOLUME_UNMUTE_ACTION` / `..._STATUS` | `"unmute"` |

### 3.5 其他模块 ID

| 常量 | 值 |
|---|---|
| `VEHICLE_MODULE_DRIVING` | 1 |
| `VEHICLE_MODULE_SENSOR` | 2 |
| `VEHICLE_MODULE_GPS` | 3 |
| `VEHICLE_MODULE_VOLUME_CONTROL` | 4 |
| `VEHICLE_MODULE_WINDOW_CONTROL` | 6 |

---

## 4. 状态回调（`ECarXInteractiveListener` / `IInteractiveCallback`）

19 个回调，全部可选覆盖：

```java
onAirConditionerInfoChanged(int type, String value)   // 空调项变化（type 见 §3.3）
onWindowInfoChanged(int type, String value)           // 车窗变化（type 见 §3.2）
onVolumeInfoChanged(int type, String value)           // 音量变化
onDrivingModeChanged(int gear)                        // 挡位变化
onDrivingStatusChanged(float speed, int wheel, int gear)
onOilInfoChanged(float level, float capacity, float remain, boolean low)
onGPSLocationChanged(String json)
onAccelerometerSensorChanged(AccelerometerData d)
onGyroscopeSensorChanged(GyroscopeData d)
onReverseCameraOpen() / onReverseCameraClose()
onVoiceWakeup(String reason)        // ★ 原车唤醒事件
onVoiceKeyLongPress()               // ★ 方控语音键长按
onStopVoice()                       // ★ 原车要求停止语音（播报中被打断）
onKeyEvent(int keyCode, boolean down)
onNaviFocusLose()
onUSBAttached()
onHMIsetAsDefault(boolean isDefault)
updateDayNightModel(boolean day)
```

> `onVoiceWakeup` / `onStopVoice` / `onVoiceKeyLongPress` 是**和原车语音系统协同**的入口：
> 我们接管语音后，可以用 `hmiRequestUseMic()` 抢占麦克风，并订阅 `onStopVoice()` 让出。

---

## 5. VehicleManager（第二层，进程内直连适配层）

来自 `ecarxinteractivesdk.jar`，底层走 `com.ecarx.xui.adaptapi.car.ICar`：

```java
VehicleManager vm = new VehicleManager();           // 无参构造
vm.register(context, infoListener, drivingListener);
vm.startWork();

float t   = vm.getHvacTemperature(VehicleZone.ZONE_ROW_1_LEFT);
int   st  = vm.getHvacState();
float min = vm.getMinHvacTemperature();
float max = vm.getMaxHvacTemperatuer();      // 注意：拼写就是 Temperatuer

vm.setHvacState(1);                          // 开/关
vm.setHvacTemperature(VehicleZone.ZONE_ROW_1_LEFT, 22.5f);

float w = vm.getWindowState(VehicleWindow.WINDOW_ROW_1_LEFT);
boolean pct = vm.isSupportWindowPercentControl();
vm.setWindowAction(VehicleWindow.WINDOW_ROW_1_LEFT, 0.5f);   // 0.0~1.0

int gear  = vm.getDrivingMode();
double sp = vm.getVehicleSpeed();
int acc   = vm.getAccStatus();
vm.stopWork(); vm.unregister();
```

### 5.1 车窗位掩码（`VehicleWindow`）

| 常量 | 值 |
|---|---|
| `WINDOW_FRONT_WINDSHIELD` | 1 |
| `WINDOW_REAR_WINDSHIELD` | 2 |
| `WINDOW_ROOF_TOP` | 4 |
| `WINDOW_ROOF_ABAT_VENT` | 8（天窗通风） |
| `WINDOW_ROW_1_LEFT` | 16 |
| `WINDOW_ROW_1_RIGHT` | 32 |
| `WINDOW_ROW_2_LEFT` | 256 |
| `WINDOW_ROW_2_RIGHT` | 512 |
| `WINDOW_ROW_3_LEFT` | 4096 |
| `WINDOW_ROW_3_RIGHT` | 8192 |

### 5.2 车门（`VehicleDoor`）

`DOOR_ROW_1_LEFT=1`、`ROW_1_RIGHT=4`、`ROW_2_LEFT=16`、`ROW_2_RIGHT=64`、`ROW_3_LEFT=256`、`ROW_3_RIGHT=1024`、`DOOR_HOOD=268435456`、`DOOR_REAR=536870912`

### 5.3 温度分区（`VehicleZone`）

`ZONE_ROW_1_LEFT=1`、`ROW_1_CENTER=2`、`ROW_1_RIGHT=4`、`ROW_1_ALL=8`
`ZONE_ROW_2_LEFT=16`、`CENTER=32`、`RIGHT=64`、`ALL=128`
`ZONE_ALL=-2147483648`

### 5.4 `VehicleManager` 回调（`IVehicleInfoChangeListener`）

```java
onHVACStateChanged(int state)
onHVACTempChanged(int zone, float temp)
onWindowInfoChanged(int window, float percent)
onOilInfoChanged(float level, float capacity, float remain, boolean low)
onDrivingStatusChanged(float speed, int gear, float wheel)
```

---

## 6. 代码示例：语音指令 → 车控

```java
// 空调调到 24 度
mgr.setAirConditionerInfo("settemp", "24");
// 关空调
mgr.setAirConditionerInfo("turnoff", "");
// 打开左前窗
mgr.setWindowInfo(110, "open", "");
// 左前窗开一半（百分比控制）
mgr.setWindowInfo(114, "open", "50");
// 音量 +2
int v = Integer.parseInt(mgr.getVolumeInfo(104));
mgr.setVolumeInfo("setvolume", String.valueOf(Math.min(v + 2, 30)));
// 静音 / 取消静音
mgr.setVolumeInfo("mute", "");
mgr.setVolumeInfo("unmute", "");
// 接管麦克风（避免与原车语音打架）
mgr.hmiRequestUseMic();
// 用完释放
mgr.hmiReleaseMic();
```

> `value` 一律是**字符串**，数字也要转字符串；返回 `"success"` / `"fail"` 或布尔。

---

## 7. 本项目的接入建议

### 7.1 立即可做（风险低）

| 场景 | 调用 |
|---|---|
| 语音「开空调」 | `setAirConditionerInfo("turnon","")` |
| 语音「空调 24 度」 | `setAirConditionerInfo("settemp","24")` |
| 语音「开左前窗」 | `setWindowInfo(110,"open","")` |
| 语音「静音」 | `setVolumeInfo("mute","")` |
| 语音「音量加 2」 | 读 104 → 写 `setvolume` |
| 播报前抢占麦克风 | `hmiRequestUseMic()` / 结束 `hmiReleaseMic()` |

### 7.2 需要先解决权限

`android.car.permission.CAR_VENDOR_EXTENSION` 是 signature 级。三条路：

1. **把我们签进平台签名**（有平台 key 的话最干净）；
2. 让原厂/售后在 `privapp-permissions` 里放行（需要系统分区写权限）；
3. 退而求其次：**不改权限，改用广播/Intent 让原车应用代替执行**（能力受限）。

已实测：`adb root` 被拒（`uid=2000(shell)`），所以走不了改系统配置的路子。

### 7.3 需要实测确认的点

| 项 | 待确认 |
|---|---|
| `setWindowInfo(114, "open", "50")` | 百分比参数是 0–100 还是 0–1 |
| `settemp` 的取值范围 | `getAirConditionerInfo(105/106)` 给出上下限后按此校验 |
| 空调分区控制 | `setAirConditionerInfo` 无 zone 参数，可能只支持主驾或全区 |
| `hmiRequestUseMic()` 效果 | 是否真能让原车语音闭嘴（需和禁用小卡方案对比） |

---

## 8. 原始文件位置（可复现）

```
car-reports/carcontrol/
├─ ECarXInteractiveAPI.jar        框架 AIDL + Manager（22 KB）
├─ ecarx.adapterapi.jar           适配层（0.89 MB）
├─ ecarxinteractivesdk.jar        客户端 SDK（22 KB，含 VehicleManager）
├─ com.ecarx.ecarxinteractiveservice.apk   服务实现（0.17 MB）
├─ j-ECarXInteractiveAPI/dump.txt          反汇编（dexdump）
├─ sdk/sdk.txt                             SDK 反汇编
└─ dex-tmp/inter.txt                       服务 APK 反汇编
```

复现命令：

```powershell
adb -s 192.168.22.197:5555 pull /system/framework/ECarXInteractiveAPI.jar .
adb -s 192.168.22.197:5555 pull /system/framework/ecarx.adapterapi.jar .
adb -s 192.168.22.197:5555 pull /system/app/ECarXInteractiveService/jar/ecarxinteractivesdk.jar .
E:\Android\Sdk\build-tools\34.0.0\dexdump.exe -d classes.dex > dump.txt
```

---

## 9. 其他相关 binder 服务（顺带记录）

| 服务名 | 接口 | 用途 |
|---|---|---|
| `ecarx_interactive` | `IInteractiveAPI` | 本文件主角 |
| `ecarx_vr_service` | — | 原车语音（小卡）内部服务 |
| `car_service` | `android.car.ICar` | 标准 Automotive |
| `ecarxappservice` | `android.app.IEcarxAppManager` | 应用管理 |
| `EcarxInputDispatcherService` | `android.content.IInputDispatcherService` | 输入分发（方控键） |

### 相关广播 Action

| Action | 含义 |
|---|---|
| `ecarx.intent.action.ECARX_RVOICEASSIST_ENTER` | 原车语音进入 |
| `ecarx.intent.action.ECARX_RVOICEASSIST_EXIT` | 原车语音退出 |
| `ecarx.intent.action.IAService.BOOT_COMPLETED` | 交互服务开机 |
| `android.intent.action.START_INTERACTIVE_SERVICE` | 交互服务启动/绑定 |
