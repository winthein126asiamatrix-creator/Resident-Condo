/// Corner radii used across the app.
///
/// Screens used to repeat `BorderRadius.circular(20)` and friends, which let the
/// cards, fields and dialogs drift apart. Everything now reads from here.
abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// Fully rounded, for status pills and badges.
  static const pill = 999.0;
}
