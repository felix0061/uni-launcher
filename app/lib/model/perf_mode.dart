import 'package:flutter/widgets.dart';

/// 性能模式开关集合（设置 → 动画效果 → 优化模式）。
///
/// 设计目的：所有"省 GPU / 省帧时间"的改动都从这里派生，关掉开关就回到
/// 改动前的行为，方便在同一台车机、同一份用户数据上做 A/B 对比。
///
/// 逐项归因：把对应的 getter 改成 `false`（或临时注释掉）单独出包，
/// 就能把"整包优化"拆成单项收益。默认全部跟随 [enabled]。
class PerfFlags {
  final bool enabled;
  const PerfFlags(this.enabled);

  static const off = PerfFlags(false);
  static const on = PerfFlags(true);

  /// 出场页快照（B1）。它依赖 `RenderRepaintBoundary.toImage`，一旦发现
  /// 动画期画面异常（例如地图区域空白），把这里改 false 即可整体回退，
  /// 不会影响其它优化项。
  static const bool allowPageSnapshot = true;

  /// A2：翻页只做竖直 60dp 位移 + 轻微缩放，不再横向整页平移。
  bool get liftMotion => enabled;

  /// A3：运动期关闭实时模糊、常驻动画与高频 tick。
  bool get motionFreeze => enabled;

  /// B2：卡片阴影/背景预烘焙成位图，避免每帧高斯。
  bool get bakedCards => enabled;

  /// B3：去掉只为阴影服务的重复裁剪层。
  bool get singleClip => enabled;

  /// B1：出场页快照，动画期只画一张位图。
  bool get pageSnapshot => enabled && allowPageSnapshot;

  /// A4：拖动时把 PointerMove 合并到帧末，只下发最后一次位置。
  bool get coalesceTouch => enabled;

  /// 1：卡片里"会自己动"的子块（能量流、频谱、进度、歌词）各自一个绘制边界。
  /// 它们刷新时只重画自己那一块，不再触发整张卡重绘。
  bool get blockBoundaries => enabled;

  /// 3：进度/歌词的刷新周期降档（进度 1s→2s、歌词检查 250ms→500ms）。
  /// 收益不大（每次只是一个小 setState），但能少一半的卡片级重绘。
  bool get tickThrottle => enabled;
}

/// 把 [PerfFlags] 交给整棵桌面树。
///
/// 不挂在主题上：主题变化会触发全树重建，而性能开关只需要一个
/// `dependOnInheritedWidgetOfExactType` 的轻量查找。
class PerfScope extends InheritedWidget {
  final PerfFlags flags;
  const PerfScope({super.key, required this.flags, required super.child});

  static PerfFlags of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PerfScope>()?.flags ??
      PerfFlags.off;

  @override
  bool updateShouldNotify(PerfScope old) =>
      old.flags.enabled != flags.enabled;
}
