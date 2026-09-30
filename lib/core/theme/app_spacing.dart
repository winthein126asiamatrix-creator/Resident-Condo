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

  /// Space above the bottom of a scroll view, before the safe area inset.
  static const pageBottom = 32.0;

  /// Gap between a label and the field below it.
  static const fieldLabelGap = 8.0;

  /// Gap between two form fields.
  static const fieldGap = 18.0;

  /// Gap between two groups on a page.
  static const sectionGap = 22.0;

  /// Gap between cards in a list.
  static const cardGap = 10.0;

  /// Height of a single line input.
  static const inputHeight = 54.0;

  /// Height of a read only picker field, such as date or time.
  static const pickerHeight = 54.0;

  /// Height of a primary or secondary button.
  static const buttonHeight = 56.0;

  /// Smallest comfortable touch target, per the platform guidelines.
  static const minTouchTarget = 48.0;
}
