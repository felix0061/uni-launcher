import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

/// 底部导航栏里的语音槽位。
///
/// 待机时它只是「空调区」和「音乐区」中间那条 41px 的缝（间距 + 分隔线）；
/// 一旦唤醒，缝隙朝两边挤开，两侧内容被压退半步，缝里浮出：
///   上面一行：此刻听到的字，像弹幕一样从右往左飘过
///   下面一枚：胶囊里的横向声波
///
/// 性能：整条槽位一个 AnimationController（宽度补间），波形一个 CustomPaint，
/// 弹幕一个 Transform。两侧压退走 Transform，不触发重新布局。
class VoiceDockSlot extends StatefulWidget {
  final bool active;
  final String state;
  final String heard;
  const VoiceDockSlot({
    super.key,
    required this.active,
    required this.state,
    this.heard = '',
  });

  @override
  State<VoiceDockSlot> createState() => _VoiceDockSlotState();
}

class _VoiceDockSlotState extends State<VoiceDockSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: widget.active ? 1 : 0);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant VoiceDockSlot old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    _c.duration = Duration(milliseconds: widget.active ? 460 : 300);
    if (widget.active) {
      _c.forward();
    } else {
      _c.reverse();
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
    // 必须挂 AnimatedBuilder：缝隙宽度是「逐帧」算出来的，光在 build 里读 _c.value
    // 只会在父级重建时跳变，看不到挤开的过程。
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // 挤出：起手快、尾巴慢，像被撑开；收回去：两端都软，别弹
        final spread = widget.active
            ? Curves.easeOutQuint.transform(_c.value)
            : Curves.easeInOutCubic.transform(_c.value);

        final base = Design.px(41); // gap 20 + 分隔线 1 + gap 20
        final extra = Design.px(268) * spread; // 比第一版更宽，弹幕才跑得开

        // 内容在缝隙开到大半时才浮出来，避免一开始就挤成一团
        final reveal = ((spread - 0.14) / 0.86).clamp(0.0, 1.0);

        return SizedBox(
          key: const ValueKey('voice-dock-slot'),
          width: base + extra,
          height: double.infinity,
          child: Stack(alignment: Alignment.center, children: [
            // 原来的分隔线：缝隙一开就淡出，让位给内容
            Opacity(
              opacity: (1 - spread * 2.4).clamp(0.0, 1.0),
              child: SizedBox(
                  height: Design.px(34),
                  width: Design.px(1),
                  child: ColoredBox(color: s.edge)),
            ),
            if (spread > 0.01)
              ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: reveal == 0 ? 0.0001 : reveal,
                  child: Opacity(
                    opacity: reveal,
                    child: _content(s, reveal),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _content(SurfaceStyle s, double reveal) {
    final h = Design.px(46);
    final w = Design.px(250);
    final heard = widget.heard.trim();
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h / 2),
        color: s.accent.withValues(alpha: .10),
        border: Border.all(
            color: s.accent.withValues(alpha: .28), width: Design.px(1)),
        boxShadow: [
          BoxShadow(
              color: s.accent.withValues(alpha: .08 + .10 * reveal),
              blurRadius: Design.px(16),
              spreadRadius: Design.px(1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(h / 2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 底层：声波
            VoiceDockWave(
                state: widget.active ? widget.state : 'idle',
                size: Size(w - Design.px(24), Design.px(26))),
            // 上层：听到的字。和胶囊同一条中缝挤出，静止时居中，长了就慢慢往左漂
            if (widget.active && heard.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      widthFactor: reveal == 0 ? 0.0001 : reveal,
                      child: Opacity(
                        opacity: reveal,
                        child: VoiceDanmaku(
                          text: heard,
                          maxWidth: w - Design.px(28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 听到的字：浮在波形上层，一动不动。
/// 出现方式是「从中间往两边、一个字一个字蹦出来」——中间的字先起，向两侧逐格推开，
/// 每字带一点回弹（easeOutBack）。文字永不滚动，长句整体等比缩小到胶囊宽度以内。
class VoiceDanmaku extends StatefulWidget {
  final String text;
  final double maxWidth;
  const VoiceDanmaku({super.key, required this.text, required this.maxWidth});

  @override
  State<VoiceDanmaku> createState() => _VoiceDanmakuState();
}

class _VoiceDanmakuState extends State<VoiceDanmaku>
    with SingleTickerProviderStateMixin {
  static const _step = .052; // 相邻两个字起跳的间隔
  static const _pop = .24; // 单个字弹出来的时长

  late final Ticker _ticker = createTicker(_onTick);
  double _t = .0;
  Duration _lastElapsed = Duration.zero;
  String _scheduled = '';
  List<double> _delay = const [];

  @override
  void initState() {
    super.initState();
    _schedule();
    if (_scheduled.isNotEmpty) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant VoiceDanmaku old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    _schedule();
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 排定每个字符的起跳时刻。
  /// 全新一句：按「离中心最近」排序，中间先、两边后；
  /// 只是接上了新识别出的几个字：接在队尾依次起跳，已经站好的字不重来（不闪）。
  void _schedule() {
    final text = widget.text;
    final n = text.length;
    if (n == 0) {
      _delay = const [];
      _scheduled = '';
      return;
    }
    if (!text.startsWith(_scheduled)) {
      _t = .0;
      _delay = List<double>.filled(n, 0);
      final center = (n - 1) / 2;
      final order = List<int>.generate(n, (i) => i)
        ..sort((a, b) => (a - center).abs().compareTo((b - center).abs()));
      for (var r = 0; r < order.length; r++) {
        _delay[order[r]] = r * _step;
      }
    } else {
      final next = _delay.isEmpty ? _t : _delay.reduce(math.max) + _step;
      final grown = [..._delay];
      var at = math.max(next, _t);
      for (var i = grown.length; i < n; i++) {
        grown.add(at);
        at += _step;
      }
      _delay = grown;
    }
    _scheduled = text;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _t += dt;
    final end = _delay.isEmpty ? 0.0 : _delay.reduce(math.max) + _pop;
    if (mounted) setState(() {});
    if (_t > end + .04) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();
    final fontSize = Design.px(19);

    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
      shadows: [
        Shadow(color: s.surface, blurRadius: Design.px(6)),
        Shadow(color: s.surface.withValues(alpha: .85), blurRadius: Design.px(2)),
      ],
    );

    // FittedBox：先按自然宽度排版，超了再整体缩小，既不动也不溢出
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < text.length; i++) _char(s, base, text[i], i),
        ],
      ),
    );
  }

  Widget _char(SurfaceStyle s, TextStyle base, String ch, int i) {
    final start = i < _delay.length ? _delay[i] : _t;
    final p = ((_t - start) / _pop).clamp(0.0, 1.0);
    // 回弹：起步略小、过冲一点点再落定，才有「蹦」的手感
    final eased = Curves.easeOutBack.transform(p);
    return Transform.scale(
      scale: .58 + .42 * eased,
      child: Opacity(
        opacity: (p * 1.7).clamp(0.0, 1.0),
        child: Text(ch, maxLines: 1, softWrap: false,
            style: base.copyWith(color: s.accent)),
      ),
    );
  }
}
/// 横向声波：待机时几乎是一条静线，说话时中间起伏最大、边缘收敛。
class VoiceDockWave extends StatefulWidget {
  final String state;
  final Size size;
  const VoiceDockWave({super.key, required this.state, this.size = const Size(196, 26)});

  @override
  State<VoiceDockWave> createState() => _VoiceDockWaveState();
}

class _VoiceDockWaveState extends State<VoiceDockWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant VoiceDockWave old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  void _sync() {
    _c.stop();
    _c.duration = switch (widget.state) {
      'listening' => const Duration(milliseconds: 2400),
      'thinking' => const Duration(milliseconds: 1000),
      'speaking' => const Duration(milliseconds: 760),
      _ => const Duration(milliseconds: 3200),
    };
    _c.repeat();
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
      builder: (context, _) => CustomPaint(
        size: widget.size,
        painter: VoiceDockWavePainter(
            state: widget.state, t: _c.value, accent: s.accent, muted: s.muted),
      ),
    );
  }
}

class VoiceDockWavePainter extends CustomPainter {
  final String state;
  final double t;
  final Color accent, muted;
  VoiceDockWavePainter(
      {required this.state,
      required this.t,
      required this.accent,
      required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 27;
    final mid = size.height / 2;
    final step = size.width / bars;
    final w = math.max(Design.px(2.4), step * .34);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < bars; i++) {
      // 越靠中间越高，边缘收成点，避免生硬的方块
      final edge = 1 - (i - (bars - 1) / 2).abs() / ((bars - 1) / 2 + .6);
      final shape = math.pow(edge, .75).toDouble();
      double amp;
      switch (state) {
        case 'listening':
          // 聆听：慢呼吸，像在听
          amp = .30 + .30 * math.sin(2 * math.pi * (t - i * .045));
          break;
        case 'thinking':
          // 识别：紧凑的跑动波，节奏快
          amp = .22 + .34 * math.sin(2 * math.pi * (t * 2.2 - i * .18));
          break;
        case 'speaking':
          // 回复：起伏大，中间最活跃
          amp = .18 +
              .52 *
                  math.sin(2 * math.pi * (t * 1.6 - i * .12)).abs() *
                  (.55 + .45 * math.sin(2 * math.pi * (t * .7 + i * .05)));
          break;
        default:
          // 待机：一条几乎静止的细线，只留一点点呼吸
          amp = .10 + .05 * math.sin(2 * math.pi * (t * .5 + i * .02));
      }
      final h = math.max(
          Design.px(1.6), (mid - Design.px(2)) * amp.abs() * shape * 2);
      final x = step * (i + .5);
      paint
        ..strokeWidth = w
        ..color = (state == 'idle' ? muted : accent).withValues(
            alpha: (.30 + .55 * amp.abs()).clamp(0.0, 1.0) * (.35 + .65 * shape));
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(VoiceDockWavePainter old) =>
      old.t != t || old.state != state || old.accent != accent;
}
