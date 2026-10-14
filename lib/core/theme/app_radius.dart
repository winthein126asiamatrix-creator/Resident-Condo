import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Corner radii used across the app.
///
/// Screens used to repeat `BorderRadius.circular(20.r)` and friends, which let the
/// cards, fields and dialogs drift apart. Everything now reads from here.
abstract final class AppRadius {
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  /// Fully rounded, for status pills and badges.
  static const double pill = 999.0;
}
