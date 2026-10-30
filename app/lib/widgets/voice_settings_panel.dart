import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/voice_settings.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

/// 语音（桌面侧）：只保留**总开关**与**跳转**。
///
/// 语音是独立项目（uni-voice 仓库）：唤醒、识别、合成、车控、媒体、导航、
/// 音色与灵敏度全都在「UNI 语音」里自己完成，桌面不再替它执行任何动作。
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
              Text('语音助手', style: TextStyle(fontSize: Design.px(26))),
              SizedBox(height: Design.px(16)),
              if (!voice.installed) ...[
                Text('语音模块未安装',
                    style: TextStyle(
                        fontSize: Design.px(20), color: s.accent)),
                SizedBox(height: Design.px(8)),
                Text('唤醒、识别和合成都装都装在独立的「UNI 语音」里。',
                    style: TextStyle(
                        fontSize: Design.px(16), color: s.muted)),
              ] else ...[
                DesignSwitchTile(
                    key: const ValueKey('voice-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用语音控制'),
                    subtitle: Text(voice.enabled
                        ? '方控语音键或直接喊唤醒词都能用'
                        : '关闭后语音模块完全停止，不录音、不耗电'),
                    value: voice.enabled,
                    onChanged: (v) => c.command('voice-enabled', enabled: v)),
                SizedBox(height: Design.px(18)),
                SizedBox(
                    height: Design.px(52),
                    child: OutlinedButton.icon(
                        key: const ValueKey('voice-open-settings'),
                        onPressed: () => c.command('voice-open-settings'),
                        icon: const Icon(Icons.tune, size: 20),
                        label: const Text('打开语音设置（音色 / 引擎 / 唤醒词）'))),
              ],
            ]));
      });
}
