import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_tokens.dart';

/// The text styles the resident facing screens use.
///
/// Sized for readability on a phone: nothing below 11sp, body copy at 13.5 to
/// 15.5, and headings at 16 to 25.
///
/// The static members below carry the shipped light palette, for the rare call
/// site that has no `BuildContext`. Screens should prefer [of], which binds the
/// same type scale to the colours of the active theme, so text follows the
/// resident's Light / Dark choice.
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

  /// The same type scale, bound to the colours of the active theme.
  static Bound of(BuildContext context) =>
      Bound(AppThemeTokens.of(context));
}

/// [AppTextStyles] resolved against a theme. Same sizes and weights, colours
/// from [AppThemeTokens].
class Bound {
  const Bound(this.tokens);

  final AppThemeTokens tokens;

  TextStyle get screenTitle => TextStyle(
        color: tokens.ink,
        fontSize: 25,
        fontWeight: FontWeight.w800,
      );

  TextStyle get sectionTitle => TextStyle(
        color: tokens.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      );

  TextStyle get cardTitle => TextStyle(
        color: tokens.ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      );

  TextStyle get body => TextStyle(color: tokens.ink, fontSize: 14);

  TextStyle get bodyStrong => TextStyle(
        color: tokens.ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      );

  TextStyle get fieldLabel => TextStyle(
        color: tokens.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      );

  TextStyle get fieldValue => TextStyle(
        color: tokens.ink,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
      );

  TextStyle get caption => TextStyle(color: tokens.muted, fontSize: 12.5);

  TextStyle get meta => TextStyle(color: tokens.faint, fontSize: 11.5);

  /// A link or other interactive label, in the brand colour.
  TextStyle get link => TextStyle(
        color: tokens.brand,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      );
}