# 0.6.13 音乐卡片与真实频谱

## 界面

- 新添加音乐卡片默认为 4×3，编辑菜单可选 4×2、4×3、4×4、8×6；已有卡片尺寸不自动改动。
- 4×2：播放器身份、封面、歌曲/歌手/专辑、窄幅频谱。
- 4×3：放大的封面/信息、频谱、可操作进度条。
- 4×4、8×6：保留左侧封面/歌曲信息、右侧多行歌词，右侧上方增加频谱。
- 音乐详情弹窗复用同一频谱组件，播放控制沿用原来的媒体会话能力判断。
- 移除天气、账号、空气、行车、电池等卡片上的同步状态文字。读数无效/超时仍显示 `—`，不会把陈旧数据伪装成实时值。

## 采集方式与权限

使用 Android `Visualizer(0)` 读取系统播放输出的 FFT，不使用麦克风采样或 `AudioRecord`，不保存/上传 PCM，不请求音频焦点、不修改音乐音量。

需要 `RECORD_AUDIO` 与 `MODIFY_AUDIO_SETTINGS`。前者会显示系统录音权限提示；没有授权时只提供“启用频谱”入口，不采样。授权成功但平台未提供 Visualizer 时保持静止，不回退到假的播放动画。Android 参考：[Visualizer](https://developer.android.com/reference/android/media/audiofx/Visualizer)。

这是**设备输出混音**，可能包含导航语音/提示音，不是对 QQ/网易云单一歌曲解码。车机 DSP、蓝牙/收音机或特殊音轨可能绕过 Android 混音；模拟器可用不代表这些实车输出都能捕获。

## 性能与生命周期

- 全进程只有一个原生 Visualizer，多个 Flutter 引擎共用。
- 原生后台线程最多 10 Hz、512 点 FFT、24 个对数频段，发往独立 EventChannel。
- Flutter 用 RepaintBoundary + CustomPainter，只重绘频谱区域，无动画 ticker；不会将 FFT 发进全局车辆/音乐状态流，也不随每个样本重建卡片。
- 多个可见消费者共享订阅；最后一个退出、暂停、切屏或应用进入后台，停止采样并释放 Visualizer。
- 对无效/非数值数据进行裁剪，最多保留 24 个归一化值。

## 验证

- Flutter analyze 无问题；146 项单元/组件测试通过。频谱测试覆盖共享消费者、权限入口、越界数值、隐藏/暂停/销毁停止，以及连续 FFT 更新不重建频谱 Widget、无动画 ticker。
- JVM 测试覆盖静音、DC/Nyquist 排除、频率映射、输出上下界。
- API28 x86_64 profile 模拟器：权限缺失状态 → 授权 → 独立测试应用播放 AudioTrack 660/1320 Hz 信号 → 实际非零 FFT → 隐藏后原生 running=false、序号停止。2 秒观察 16 帧，不超过 10 Hz 上限。
- 四种卡片尺寸及音乐详情弹窗无布局异常，截图在 `app/verification/audio-spectrum/`，测试数据中的歌曲名/封面占位只服务于界面验证；频谱来自真实 AudioTrack 输出。
- 最终 release/AOT 另有 6 项启动、持久化、设置和空闲采样检查通过。
- 全局面板生命周期、低内存通知和重新打开单独回归；内存结果见 `MEMORY_0_6_12.md`。

```sh
python3 tools/test_audio_spectrum.py --install-fixture
python3 app/tools/flutter_task.py drive \
  --driver=test_driver/audio_spectrum_driver.dart \
  --target=integration_test/audio_spectrum_test.dart --profile -d emulator-5580
```

测试会给模拟器中的测试版授权录音、播放短测试音并在结束后停止。初始必须没有 RECORD_AUDIO 授权；Flutter drive 卸载集成测试版后的下一次安装即满足。测试音应用只允许模拟器安装，不包含在发布 APK 中。

频谱本身的内存对照、30 次重建和 180 秒持续采样结果，见 [频谱内存专项评估](AUDIO_SPECTRUM_MEMORY.md)。

## 车机待验证

1. QQ、网易云分别播放，授权后确认频谱响应；暂停、切屏、返回其他应用后核对采样关闭。
2. 音乐弹窗与卡片同时可见时只有一份采集，方向盘切歌/仪表盘信息不受影响。
3. 导航播报和蓝牙音乐是否经过可捕获的混音链路。
4. 连续运行 20–30 分钟，同时观察主桌面、地图和播放器内存与系统低内存事件。
