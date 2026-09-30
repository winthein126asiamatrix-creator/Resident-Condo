import 'package:flutter/material.dart';

import 'app_palette.dart';

/// The text styles the resident facing screens use.
///
/// Sized for readability on a phone: nothing below 11sp, body copy at 13.5 to
/// 15.5, and headings at 16 to 25.
abstract final class AppTextStyles {
  /// Screen level heading, e.g. "Facilities".
  static const screenTitle = TextStyle(
    color: AppPalette.ink,
    fontSize: 25,
    fontWeight: FontWeight.w800,
  );

  /// Group heading inside a screen, e.g. "Your requests".
  static const sectionTitle = TextStyle(
    color: AppPalette.ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// Card title, e.g. a facility or request name.
  static const cardTitle = TextStyle(
    color: AppPalette.ink,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  /// Default reading size.
  static const body = TextStyle(color: AppPalette.ink, fontSize: 14);

  /// Reading size with emphasis, the most common weight in a card.
  static const bodyStrong = TextStyle(
    color: AppPalette.ink,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Field label above an input.
  static const fieldLabel = TextStyle(
    color: AppPalette.ink,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  );

  /// Text inside an input.
  static const fieldValue = TextStyle(
    color: AppPalette.ink,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
  );

  /// Supporting line under a heading or field.
  static const caption = TextStyle(color: AppPalette.muted, fontSize: 12.5);

  /// Smallest text still used, for meta lines such as a reference id.
  static const meta = TextStyle(color: AppPalette.faint, fontSize: 11.5);
}
