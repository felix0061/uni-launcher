# Android 9 交互采样

这组工具记录真实设备上的有界操作窗口，不把等待时间混入连续滑动 FPS，也不把 Flutter 消费纹理次数当作高德产帧数。测试结果见 `docs/CAR_PERFORMANCE_FINDINGS_2026_10_30.md`。

## 文件

- `PacedInput.java`：以约 60Hz 注入一次手势，打印设备 uptime 时间边界；普通 `input swipe` 的内部循环没有相同的频率约束。合成手势不能代表触摸屏硬件采样延迟。
- `measure_interaction.py`：一次操作的前后截图、状态、线程、5 秒 atrace、操作时间戳，以及 SurfaceFlinger 图层呈现记录。采样期间轮询 SF，避免 128 项环形缓冲覆盖掉操作开头。
- `analyze_interaction.py`：在操作时间窗内计算呈现间隔、sched CPU 运行时间、atrace 同步切片。切片耗时是包含子项的墙钟耗时，不可相加当总 CPU。
- `test_analyze_interaction.py`：验证时间窗裁切、CPU 计算、重复呈现样本去重和切片时间；不连接设备。

## 构建和运行

在仓库根目录运行，按本机路径修改 JDK/SDK/ADB。临时编译目录与设备 helper 路径仅用于诊断：

```powershell
$perfBuild = Join-Path $env:TEMP 'uni-paced-input'
New-Item -ItemType Directory -Path $perfBuild -Force | Out-Null
javac -source 8 -target 8 -cp E:\Android\Sdk\platforms\android-34\android.jar -d $perfBuild tools\perf\PacedInput.java
E:\Android\Sdk\build-tools\36.0.0\d8.bat --lib E:\Android\Sdk\platforms\android-34\android.jar --output $perfBuild "$perfBuild\PacedInput.class"
D:\platform-tools\adb.exe -s 车机地址:5555 push "$perfBuild\classes.dex" /data/local/tmp/uni-paced-input.dex
```

先观察当前截图，选择不落在控件上的坐标，确认地图、页面、主题、缩放设置和实际前台应用。以下是本次布局下从天气卡空白处向左翻页的例子，不能当作所有布局的固定坐标：

```powershell
python tools/perf/measure_interaction.py --adb D:\platform-tools\adb.exe --serial 车机地址:5555 --output car-reports/perf/example-page --swipe 1800 940 100 940 2500
python tools/perf/analyze_interaction.py car-reports/perf/example-page
python tools/perf/test_analyze_interaction.py
```

`--idle 3` 采空闲，`--tap X Y` 采一次 50ms 点击。点击分析使用按下之后的 500ms 观察窗，**不能把整个窗的 presentRate 当成动画 FPS，也不能把窗内第一个帧无条件归因于点击**。

手势最长 3 秒；地图默认包名 `com.autonavi.amapautp.yh`，可用 `--map-package` 修改。输出目录必须不存在，以防覆盖证据。工具不会自动验证页面是否切换：必须检查 before/after 状态和截图，排除弹窗、地图抢占、搜索页、未发生切页等样本。`traceCoversAction=false` 的结果也不得使用。

结束后恢复临时调整的设置，可删除本次放入设备的 helper：

```powershell
D:\platform-tools\adb.exe -s 车机地址:5555 shell rm /data/local/tmp/uni-paced-input.dex
```

采集会增加系统负载；后台 App、首次启动/resize、地图视角、温度、导航状态及采集方式必须随对照记录。release trace 不含完整 Dart build/raster 阶段，不能据此声称已定位到某个 Dart 函数。
