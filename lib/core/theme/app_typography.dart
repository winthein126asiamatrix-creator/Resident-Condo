import 'package:flutter/material.dart';

/// Typography helpers for the resident app.
///
/// English uses DM Sans; Myanmar (Burmese Unicode) uses Pyidaungsu. Rather
/// than relying on [TextStyle.fontFamilyFallback] alone, these helpers inspect
/// the actual text and choose a primary family that can shape it correctly,
/// while still keeping the other family as a fallback for mixed-language
/// strings such as "Unit A-101".
abstract final class AppTypography {
  static const String englishFamily = 'DM Sans';
  static const String myanmarFamily = 'Pyidaungsu';

  static const List<String> latinFallback = <String>['Pyidaungsu'];
  static const List<String> myanmarFallback = <String>['DM Sans'];

  /// {@template app_typography.isMyanmar}
  /// Whether [text] contains Burmese Unicode code points in the main Myanmar
  /// block (U+1000..U+109F), which includes consonants, vowel signs and tone
  /// marks.
  /// {@endtemplate}
  static bool containsMyanmar(String? text) {
    if (text == null || text.isEmpty) return false;
    for (final rune in text.runes) {
      if (rune >= 0x1000 && rune <= 0x109F) return true;
    }
    return false;
  }

  /// Primary family for a piece of text. Mixed strings that contain any
  /// Myanmar character use Pyidaungsu (with DM Sans as fallback); otherwise
  /// DM Sans (with Pyidaungsu as fallback).
  static String familyFor(String? text) =>
      containsMyanmar(text) ? myanmarFamily : englishFamily;

  static List<String> fallbackFor(String? text) =>
      containsMyanmar(text) ? myanmarFallback : latinFallback;

  /// Applies the appropriate family and fallback to [base] without changing the
  /// size, weight, colour or other properties.
  static TextStyle resolve(TextStyle base, {String? text}) {
    return base.copyWith(
      fontFamily: familyFor(text),
      fontFamilyFallback: fallbackFor(text),
    );
  }
}
