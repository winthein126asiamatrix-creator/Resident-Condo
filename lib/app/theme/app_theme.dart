import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Builds the app's [ThemeData] from a brand seed colour.
///
/// Material 3's `ColorScheme.fromSeed` derives the tonal palette, and
/// [AppThemeTokens] carries the neutral surfaces alongside it. Keeping both in
/// one place is what lets the Appearance screen offer a colour and have the
/// whole app follow.
abstract final class AppTheme {
  /// The colour the app shipped with, used by "Reset to Default".
  static const defaultSeed = AppPalette.brand;

  static ThemeData get light => forSeed(defaultSeed, Brightness.light);

  static ThemeData get dark => forSeed(defaultSeed, Brightness.dark);

  /// The Material 3 scheme for a seed, exposed so screens that preview a colour
  /// (the Appearance screen) paint with exactly what the app will use.
  ///
  /// `ColorScheme.fromSeed` is used for the tonal palette, then the primary is
  /// overridden with the seed itself in light mode. Without that override a
  /// resident who taps Indigo would get a slightly different indigo on the
  /// Material controls (radio, checkbox, switch, cursor) than on the buttons,
  /// because those read `colorScheme.primary` while the buttons read the
  /// token. Overriding keeps one brand colour across both.
  ///
  /// Dark mode keeps the generated primary: the raw seed would be too dark to
  /// read against a dark canvas.
  static ColorScheme schemeFor(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (brightness == Brightness.light) {
      return scheme.copyWith(
        primary: seed,
        onPrimary: AppThemeTokens.onColor(seed),
      );
    }
    return scheme;
  }

  static ThemeData forSeed(Color seed, Brightness brightness) {
    final colorScheme = schemeFor(seed, brightness);
    final tokens = AppThemeTokens.from(colorScheme, seed);
    final dark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvas,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.brandSoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tokens.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? tokens.brand : tokens.muted,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.brand,
        linearTrackColor: tokens.surfaceMuted,
        circularTrackColor: tokens.surfaceMuted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF23302E) : const Color(0xFF1D2B2A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.brand,
        inactiveTrackColor: tokens.surfaceMuted,
        thumbColor: tokens.brand,
        overlayColor: tokens.brand.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}