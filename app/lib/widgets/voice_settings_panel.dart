import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/voice_settings.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';
import 'voice_wave.dart';

/// 语音助手设置面板：开关默认关，关闭时服务彻底停止、零后台开销。
/// 车控指令只走本地规则；音色取 Edge-TTS 预置音色（不做声音克隆）。
class VoiceSettingsPanel extends StatelessWidget {
  final LauncherController controller;
  const VoiceSettingsPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: controller.native,
      builder: (context, n, _) {
        final c = controller, s = SurfaceStyle.of(context);
        final voice = VoiceSettings(
            n['voice'] is Map ? Map<String, dynamic>.from(n['voice']) : {});
        return GlassSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Row(children: [
                Expanded(
                    child: Text('语音助手',
                        style: TextStyle(fontSize: Design.px(26)))),
                if (voice.enabled)
                  Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: Design.px(14),
                          vertical: Design.px(6)),
                      decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: .12),
                          borderRadius:
                              BorderRadius.circular(s.controlRadius)),
                      child: Text(voice.stateLabel,
                          style: TextStyle(
                              fontSize: Design.px(16), color: s.accent)))
              ]),
              SizedBox(height: Design.px(16)),
              DesignSwitchTile(
                  key: const ValueKey('voice-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用语音控制'),
                  subtitle: Text(voice.enabled
                      ? '方控语音键或说出「${voice.wakeWord}」唤醒'
                      : '关闭后服务完全停止，不录音、不耗电'),
                  value: voice.enabled,
                  onChanged: (v) => c.command('voice-enabled', enabled: v)),
              SizedBox(height: Design.px(8)),
              Center(
                  child: VoiceWave(
                      state: voice.enabled ? voice.state : 'idle',
                      size: Design.px(150))),
              SizedBox(height: Design.px(8)),
              Text('唤醒词：${voice.wakeWord}',
                  style: TextStyle(
                      fontSize: Design.px(19), color: s.muted)),
              SizedBox(height: Design.px(20)),
              _divider(s),
              DropdownButtonFormField<String>(
                  key: const ValueKey('voice-voice-id'),
                  initialValue: voice.voiceId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '语音音色'),
                  items: [
                    for (final group in voiceCatalog)
                      for (final option in group.options)
                        DropdownMenuItem(
                            value: option.id,
                            child: Text('${option.label} · ${group.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) {
                    if (v != null) c.command('voice-voice-id', value: v);
                  }),
              SizedBox(height: Design.px(12)),
              _slider(s, c, 'voice-speed', '语速', voice.speed, -50, 100, 10),
              _slider(s, c, 'voice-pitch', '音调', voice.pitch, -20, 20, 4),
              SizedBox(height: Design.px(8)),
              Text('唤醒灵敏度（音乐/导航播放时自动再降一档）',
                  style: TextStyle(
                      fontSize: Design.px(17), color: s.muted)),
              SizedBox(height: Design.px(10)),
              Wrap(spacing: Design.px(14), runSpacing: Design.px(10), children: [
                for (final (label, level) in const [
                  ('低', 1),
                  ('中', 2),
                  ('高', 3)
                ])
                  ChoiceChip(
                      key: ValueKey('voice-sensitivity-$level'),
                      label: Text(label),
                      selected: voice.wakeSensitivity == level,
                      side: s.technicalFrame
                          ? s.controlSide(voice.wakeSensitivity == level)
                          : null,
                      shape: s.controlShape(
                          selected: voice.wakeSensitivity == level),
                      onSelected: (_) =>
                          c.command('voice-sensitivity', value: '$level'))
              ]),
              SizedBox(height: Design.px(16)),
              _divider(s),
              DesignSwitchTile(
                  key: const ValueKey('voice-tts-mix'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('播报时允许与音乐同播'),
                  subtitle: const Text('关闭后播报会压低音乐/导航音量'),
                  value: voice.ttsMixMode == 'coexist',
                  onChanged: (v) =>
                      c.command('voice-tts-mix', value: v ? 'coexist' : 'duck')),
              DesignSwitchTile(
                  key: const ValueKey('voice-continuous'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('连续对话'),
                  subtitle: const Text('回复结束后继续聆听，支持多轮指令'),
                  value: voice.continuous,
                  onChanged: (v) => c.command('voice-continuous', enabled: v)),
              DesignSwitchTile(
                  key: const ValueKey('voice-cloud'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('云端闲聊问答'),
                  subtitle: const Text('仅处理闲聊/问答；车控指令始终在本地执行'),
                  value: voice.cloudEnabled,
                  onChanged: (v) => c.command('voice-cloud', enabled: v)),
            ]));
      });

  Widget _divider(SurfaceStyle s) => Container(height: 1, color: s.edge);

  Widget _slider(SurfaceStyle s, LauncherController c, String action,
      String label, int current, double min, double max, int divisions) {
    return StatefulBuilder(builder: (context, setLocal) {
      double? drag;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label：${(drag ?? current.toDouble()).round()}',
            style: TextStyle(fontSize: Design.px(19), color: s.muted)),
        Slider(
            value: (drag ?? current.toDouble()).clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => setLocal(() => drag = v),
            onChangeEnd: (v) {
              c.command(action, value: '${v.round()}');
              drag = null;
              setLocal(() {});
            })
      ]);
    });
  }
}
