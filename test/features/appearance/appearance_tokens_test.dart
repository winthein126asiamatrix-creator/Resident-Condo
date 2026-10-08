import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test/core/theme/app_palette.dart';
import 'package:test/core/theme/app_theme_tokens.dart';

void main() {
  group('AppThemeTokens', () {
    test('derives neutrals that stay grey while carrying the seed hue', () {
      const blue = Color(0xFF2563EB);
      const orange = Color(0xFFEA580C);
      final blueScheme = ColorScheme.fromSeed(seedColor: blue);
      final orangeScheme = ColorScheme.fromSeed(seedColor: orange);

      final blueTokens = AppThemeTokens.from(blueScheme, blue);
      final orangeTokens = AppThemeTokens.from(orangeScheme, orange);

      // Ink and muted must read as neutrals, not as tinted brand colours, or the
      // whole app takes on the brand hue.
      for (final tokens in [blueTokens, orangeTokens]) {
        expect(tokens.ink.computeLuminance(), lessThan(0.2));
        expect(HSLColor.fromColor(tokens.muted).saturation, lessThan(0.2));
        expect(tokens.surface.computeLuminance(), greaterThan(0.9));
      }

      // Two different seeds must not produce the same surface, or the tinting
      // is not doing anything.
      expect(blueTokens.border, isNot(orangeTokens.border));
    });

    test('the brand colour is the seed itself in light mode', () {
      const seed = Color(0xFF9333EA);
      final scheme = ColorScheme.fromSeed(seedColor: seed);
      final tokens = AppThemeTokens.from(scheme, seed);

      // Picking a colour gives that exact colour, not a tonal shift of it.
      expect(tokens.brand, seed);
      expect(tokens.onBrand, Colors.white);
      expect(tokens.brandSoft, scheme.primaryContainer);
    });

    test('a bright seed gets dark text on the brand fill', () {
      const seed = Color(0xFFFCD34D);
      final tokens = AppThemeTokens.from(
        ColorScheme.fromSeed(seedColor: seed),
        seed,
      );

      // White on a pale amber would be unreadable.
      expect(tokens.brand, seed);
      expect(tokens.onBrand, isNot(Colors.white));
      expect(tokens.onBrand.computeLuminance(), lessThan(0.2));
    });

    test('dark mode inverts the surface hierarchy', () {
      const seed = Color(0xFF0F766E);
      final light = AppThemeTokens.from(
        ColorScheme.fromSeed(seedColor: seed),
        seed,
      );
      final dark = AppThemeTokens.from(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        seed,
      );

      expect(light.isDark, isFalse);
      expect(dark.isDark, isTrue);
      // Dark: canvas darker than cards, ink lighter than cards.
      expect(dark.canvas.computeLuminance(), lessThan(dark.surface.computeLuminance()));
      expect(dark.ink.computeLuminance(), greaterThan(dark.surface.computeLuminance()));
    });

    test('falls back to the shipped teal palette with no extension', () {
      final fallback = AppThemeTokens.fallback();

      expect(fallback.seed, AppPalette.brand);
      expect(fallback.isDark, isFalse);
    });

    test('onColor picks readable ink for a swatch fill', () {
      expect(
        AppThemeTokens.onColor(const Color(0xFFFCD34D)),
        AppPalette.ink,
      );
      expect(AppThemeTokens.onColor(const Color(0xFF1D2B2A)), Colors.white);
    });

    test('lerp moves between two palettes without throwing', () {
      const from = Color(0xFF2563EB);
      const to = Color(0xFFEA580C);
      final a = AppThemeTokens.from(ColorScheme.fromSeed(seedColor: from), from);
      final b = AppThemeTokens.from(ColorScheme.fromSeed(seedColor: to), to);

      final midpoint = a.lerp(b, 0.5);

      expect(midpoint.brand, isNot(a.brand));
      expect(midpoint.ink.computeLuminance(), lessThan(0.5));
      expect(a.lerp(null, 0.5), same(a));
    });
  });
}