import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/voice_settings.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'voice_wave.dart';

/// 桌面内的全局语音反馈：唤醒后从底部浮现的波纹 + 状态文字。
/// 仅激活态渲染动画，其余时间 AnimatedOpacity 置零并由 TickerMode 停表省电。
class VoiceOverlay extends StatelessWidget {
  final LauncherController controller;
  final double size;
  const VoiceOverlay({super.key, required this.controller, this.size = 150});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: controller.native,
      builder: (context, n, _) {
        final voice = VoiceSettings(
            n['voice'] is Map ? Map<String, dynamic>.from(n['voice']) : {});
        final active = voice.enabled && voice.activeFeedback;
        final s = SurfaceStyle.of(context);
        return AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: Duration(milliseconds: active ? 220 : 420),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TickerMode(
                  enabled: active,
                  child: VoiceWave(state: voice.state, size: size)),
              SizedBox(height: Design.px(6)),
              Text(voice.stateLabel,
                  style: TextStyle(
                      fontSize: Design.px(20),
                      color: s.accent,
                      fontWeight: FontWeight.w500))
            ])));
      });
}

/// 全局底栏顶部的呼吸光带：语音激活时提示，不占用 dock 空间。
class VoiceDockGlow extends StatefulWidget {
  final bool active;
  const VoiceDockGlow({super.key, required this.active});
  @override
  State<VoiceDockGlow> createState() => _VoiceDockGlowState();
}

class _VoiceDockGlowState extends State<VoiceDockGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceDockGlow old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => IgnorePointer(
            child: AnimatedOpacity(
                opacity: widget.active ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                child: Container(
                    height: Design.px(3),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      s.accent.withValues(alpha: 0),
                      s.accent.withValues(alpha: .15 + _c.value * .5),
                      s.accent.withValues(alpha: 0)
                    ]))))));
  }
}
