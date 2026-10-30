/// 语音总开关的模型：语音已拆成独立 App（xyz.i4o.uni.voice）单独安装，
/// 桌面这边只关心「装没装、开没开、现在在干嘛」，音色/灵敏度/云端都在语音 App 里调。
class VoiceSettings {
  final Map<String, dynamic> raw;
  const VoiceSettings(this.raw);

  /// 语音模块是否已安装（没装就提示去安装，开关点了没意义）。
  bool get installed => raw['installed'] == true;
  bool get enabled => raw['enabled'] == true;
  String get state => '${raw['state'] ?? 'idle'}';
  String get source => '${raw['source'] ?? ''}';
  String get wakeWord => '${raw['wakeWord'] ?? '你好 小优'}';
  /// 本地引擎类型：sherpa（真实离线 KWS/ASR）或 stub（降级桩）。
  String get engine => '${raw['engine'] ?? 'stub'}';
  bool get isSherpaEngine => engine == 'sherpa';
  /// 离线 TTS 是否就绪。
  bool get ttsOffline => raw['ttsOffline'] == true;

  /// 桌面 → 语音 指令的回执：对方没响应/未安装/权限被拒时非空。
  String get controlError => '${raw['controlError'] ?? ''}';

  /// 是否处于需要视觉反馈的激活态（聆听/识别/回复）。
  bool get activeFeedback => const {'listening', 'thinking', 'speaking'}.contains(state);

  String get stateLabel => switch (state) {
        'idle' => '待机',
        'listening' => '聆听中',
        'thinking' => '识别中',
        'speaking' => '回复中',
        'unavailable' => '麦克风不可用',
        _ => state,
      };

  /// 桌面面板上的一行说明。
  String get summary {
    if (!installed) return '语音模块未安装';
    if (!enabled) return '已关闭';
    return stateLabel;
  }
}
