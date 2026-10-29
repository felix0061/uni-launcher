/// 语音助手的快照模型：直接包一层 native 快照里的 `voice` 块。
/// 音色目录取 Edge-TTS 预置音色（不做声音克隆），默认小智台湾腔。
class VoiceSettings {
  final Map<String, dynamic> raw;
  const VoiceSettings(this.raw);

  bool get enabled => raw['enabled'] == true;
  bool get available => raw['available'] == true;
  String get state => '${raw['state'] ?? 'idle'}';
  String get source => '${raw['source'] ?? ''}';
  String get wakeWord => '${raw['wakeWord'] ?? '你好 小U'}';
  String get voiceId => '${raw['voiceId'] ?? defaultVoiceId}';
  int get speed => (raw['speed'] ?? 0) as int;
  int get pitch => (raw['pitch'] ?? 0) as int;
  int get wakeSensitivity => (raw['wakeSensitivity'] ?? 2) as int;
  String get ttsMixMode => '${raw['ttsMixMode'] ?? 'duck'}';
  bool get continuous => raw['continuous'] != false;
  bool get localOnly => raw['localOnly'] != false;
  bool get cloudEnabled => raw['cloudEnabled'] == true;

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

  static const defaultVoiceId = 'zh-TW-HsiaoYuNeural';
  static String voiceLabel(String id) {
    for (final group in voiceCatalog) {
      for (final option in group.options) {
        if (option.id == id) return option.label;
      }
    }
    return id;
  }
}

class VoiceOption {
  final String id, label;
  const VoiceOption(this.id, this.label);
}

class VoiceGroup {
  final String title;
  final List<VoiceOption> options;
  const VoiceGroup(this.title, this.options);
}

/// Edge-TTS 中文预置音色：台湾腔优先，其次大陆/粤语，足够丰富且零克隆成本。
const voiceCatalog = <VoiceGroup>[
  VoiceGroup('台湾腔（默认）', [
    VoiceOption('zh-TW-HsiaoYuNeural', '晓雨 · 女 · 温润'),
    VoiceOption('zh-TW-HsiaoChenNeural', '晓臻 · 女 · 清亮'),
    VoiceOption('zh-TW-YunJheNeural', '雲哲 · 男 · 沉稳'),
  ]),
  VoiceGroup('普通话', [
    VoiceOption('zh-CN-XiaoxiaoNeural', '晓晓 · 女 · 自然'),
    VoiceOption('zh-CN-XiaoyiNeural', '晓伊 · 女 · 活泼'),
    VoiceOption('zh-CN-YunjianNeural', '云健 · 男 · 浑厚'),
    VoiceOption('zh-CN-YunxiNeural', '云希 · 男 · 阳光'),
    VoiceOption('zh-CN-YunxiaNeural', '云夏 · 男 · 少年'),
    VoiceOption('zh-CN-YunyangNeural', '云扬 · 男 · 播音'),
  ]),
  VoiceGroup('方言特色', [
    VoiceOption('zh-CN-liaoning-XiaobeiNeural', '晓北 · 女 · 东北'),
    VoiceOption('zh-CN-shaanxi-XiaoniNeural', '晓妮 · 女 · 陕西'),
  ]),
  VoiceGroup('粤语', [
    VoiceOption('zh-HK-HiuGaaiNeural', '曉佳 · 女'),
    VoiceOption('zh-HK-HiuMaanNeural', '曉曼 · 女'),
    VoiceOption('zh-HK-WanLungNeural', '雲龍 · 男'),
  ]),
];
