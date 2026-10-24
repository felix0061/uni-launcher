/// The reviewed artwork is 1920 px wide; the launcher lays out at 1600 units.
/// Keep every design measurement explicit instead of inheriting Material defaults.
abstract final class Design {
  static const canvasWidth = 1600.0;
  static const artworkWidth = 1920.0;
  static double px(num value) => value * canvasWidth / artworkWidth;
}
