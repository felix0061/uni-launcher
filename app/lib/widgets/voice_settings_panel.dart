import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/voice_settings.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

/// 语音设置（桌面侧）：语音已拆成独立 App 单独安装，这里只保留总开关，
/// 音色、引擎（本地离线 / 火山引擎）、灵敏度、云端对话都在语音 App 里设置。
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
                if (voice.installed && voice.enabled)
                  Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: Design.px(14), vertical: Design.px(6)),
                      decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(s.controlRadius)),
                      child: Text(voice.stateLabel,
                          style: TextStyle(
                              fontSize: Design.px(16), color: s.accent)))
              ]),
              SizedBox(height: Design.px(16)),
              if (!voice.installed) ...[
                Text('语音模块未安装',
                    style: TextStyle(
                        fontSize: Design.px(20), color: s.accent)),
                SizedBox(height: Design.px(8)),
                Text(
                    '唤醒、识别和合成都在独立的「UNI 语音」里，'
                    '不需要语音的话桌面就不用装那百来兆的模型。',
                    style: TextStyle(fontSize: Design.px(16), color: s.muted)),
              ] else ...[
                DesignSwitchTile(
                    key: const ValueKey('voice-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用语音控制'),
                    subtitle: Text(voice.enabled
                        ? '方控语音键或说出「${voice.wakeWord}」唤醒'
                        : '关闭后语音模块完全停止，不录音、不耗电'),
                    value: voice.enabled,
                    onChanged: (v) => c.command('voice-enabled', enabled: v)),
                if (voice.controlError.isNotEmpty) ...[
                  SizedBox(height: Design.px(4)),
                  Text(voice.controlError,
                      style: TextStyle(
                          fontSize: Design.px(16), color: s.accent)),
                  Text('提示：语音模块装好后要先打开一次，系统才允许后台接收指令。',
                      style:
                          TextStyle(fontSize: Design.px(14), color: s.muted)),
                ],
                if (voice.installed && voice.state == 'unavailable') ...[
                  SizedBox(height: Design.px(4)),
                  Text('麦克风权限没给「UNI 语音」：点上面的开关会跳到语音设置页弹授权框，'
                      '允了就能用（桌面自己的麦克风权限不算数，两个包各授各的）。',
                      style: TextStyle(
                          fontSize: Design.px(14), color: s.accent)),
                ],
                SizedBox(height: Design.px(10)),
                Text('唤醒词：${voice.wakeWord}',
                    style: TextStyle(fontSize: Design.px(19), color: s.muted)),
                SizedBox(height: Design.px(6)),
                Text(
                    voice.isSherpaEngine
                        ? '本地离线识别已就绪'
                        : '识别引擎降级：唤醒词暂不可用，方控键仍可触发',
                    style: TextStyle(
                        fontSize: Design.px(16),
                        color: voice.isSherpaEngine ? s.muted : s.accent)),
                SizedBox(height: Design.px(18)),
                SizedBox(
                    height: Design.px(52),
                    child: OutlinedButton.icon(
                        key: const ValueKey('voice-open-settings'),
                        onPressed: () => c.command('voice-open-settings'),
                        icon: const Icon(Icons.tune, size: 20),
                        label: const Text('打开语音设置（音色 / 引擎 / 灵敏度）'))),
              ],
            ]));
      });
}
