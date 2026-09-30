/// Layout rhythm shared by the screens.
///
/// The screens used to repeat the same numbers in every page, which made it easy
/// for one of them to drift. These are the values the design system is built
/// on, so a page that needs the standard spacing reads it from here.
abstract final class AppSpacing {
  /// Horizontal gutter shared by every screen.
  static const gutter = 20.0;

  /// Space kept above the first element of a page, measured from the system top
  /// inset. The SafeArea based screens add it to their list padding, and the
  /// custom app bar adds it above its own content.
  static const pageTop = 18.0;
}
