import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  static TextStyle get screenTitle => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 26.sp,
    fontWeight: FontWeight.w800,
  );

  /// Group heading inside a screen, e.g. "Your requests".
  static TextStyle get sectionTitle => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 17.sp,
    fontWeight: FontWeight.w800,
  );

  /// Card title, e.g. a facility or request name.
  static TextStyle get cardTitle => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 16.sp,
    fontWeight: FontWeight.w800,
  );

  /// Default reading size.
  static TextStyle get body => TextStyle(color: AppPalette.ink, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 15.sp);

  /// Reading size with emphasis, the most common weight in a card.
  static TextStyle get bodyStrong => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 15.sp,
    fontWeight: FontWeight.w700,
  );

  /// Field label above an input.
  static TextStyle get fieldLabel => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 14.5.sp,
    fontWeight: FontWeight.w700,
  );

  /// Text inside an input.
  static TextStyle get fieldValue => TextStyle(
    color: AppPalette.ink,
    fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 16.5.sp,
    fontWeight: FontWeight.w600,
  );

  /// Supporting line under a heading or field.
  static TextStyle get caption => TextStyle(color: AppPalette.muted, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 13.5.sp);

  /// Smallest text still used, for meta lines such as a reference id.
  static TextStyle get meta => TextStyle(color: AppPalette.faint, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 12.5.sp);

  /// The same type scale, bound to the colours of the active theme.
  static Bound of(BuildContext context) =>
      Bound(AppThemeTokens.of(context));
}

/// [AppTextStyles] resolved against a theme. Same sizes and weights, colours
/// from [AppThemeTokens].
class Bound {
  Bound(this.tokens);

  final AppThemeTokens tokens;

  TextStyle get screenTitle => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 26.sp,
        fontWeight: FontWeight.w800,
      );

  TextStyle get sectionTitle => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 17.sp,
        fontWeight: FontWeight.w800,
      );

  TextStyle get cardTitle => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 16.sp,
        fontWeight: FontWeight.w800,
      );

  TextStyle get body => TextStyle(color: tokens.ink, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 15.sp);

  TextStyle get bodyStrong => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      );

  TextStyle get fieldLabel => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 14.5.sp,
        fontWeight: FontWeight.w700,
      );

  TextStyle get fieldValue => TextStyle(
        color: tokens.ink,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 16.5.sp,
        fontWeight: FontWeight.w600,
      );

  TextStyle get caption => TextStyle(color: tokens.muted, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 13.5.sp);

  TextStyle get meta => TextStyle(color: tokens.faint, fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 12.5.sp);

  /// A link or other interactive label, in the brand colour.
  TextStyle get link => TextStyle(
        color: tokens.brand,
        fontFamily: 'DM Sans',

        fontFamilyFallback: const ['Pyidaungsu'],
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      );
}
