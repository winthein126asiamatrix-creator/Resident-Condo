import 'package:flutter/material.dart';

/// The design system colours that follow the resident's chosen brand colour.
///
/// [AppPalette] holds the fixed light values the app shipped with. This
/// extension carries the same roles, but derived from the active seed, so a
/// resident picking a different primary colour sees it reach the buttons,
/// panels, cards and borders rather than only the colour swatch they tapped.
///
/// Neutrals are derived with a very low saturation taken from the seed's hue.
/// That keeps a blue theme cool and a warm theme warm without ever letting the
/// greys turn colourful.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.seed,
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.ink,
    required this.muted,
    required this.mutedStrong,
    required this.faint,
    required this.brand,
    required this.onBrand,
    required this.brandDark,
    required this.brandSoft,
    required this.brandTint,
    required this.brandBorder,
    required this.brandOnDark,
    required this.brandOnDarkMuted,
    required this.heroShadow,
    required this.cardShadow,
  });

  /// Builds the tokens for a Material 3 scheme produced from a seed colour.
  factory AppThemeTokens.from(ColorScheme scheme, Color seed) {
    final hsl = HSLColor.fromColor(seed);
    final dark = scheme.brightness == Brightness.dark;

    /// A grey that still carries a trace of the seed's hue, so a blue theme
    /// stays cool and a warm theme stays warm without ever looking coloured.
    Color neutral(double saturation, double lightness) =>
        HSLColor.fromAHSL(1, hsl.hue, saturation, lightness).toColor();

    // The fill a solid brand element (button, hero panel, selected control)
    // paints with. In light mode that is the seed itself: picking Teal gives
    // exactly Teal, which is what a resident expects when they tap a swatch. In
    // dark mode the raw seed would be unreadably dark against the canvas, so the
    // scheme's lighter primary is used instead.
    final brand = dark ? scheme.primary : seed;

    // Text or an icon drawn on that fill. In dark mode the fill is light, so the
    // scheme's dark on-colour is right. In light mode the fill's own luminance
    // decides, so a bright Amber or Lime gets the theme's dark ink and a dark
    // Teal gets white rather than a contrast pair that fails WCAG.
    final lightInk = neutral(0.28, 0.145);
    final onBrand = dark
        ? scheme.onPrimary
        : (brand.computeLuminance() > 0.45 ? lightInk : Colors.white);

    return AppThemeTokens(
      seed: seed,
      brightness: scheme.brightness,
      canvas: dark ? neutral(0.14, 0.08) : neutral(0.14, 0.978),
      surface: dark ? neutral(0.10, 0.115) : Colors.white,
      surfaceMuted: dark ? neutral(0.10, 0.155) : neutral(0.18, 0.957),
      border: dark ? neutral(0.08, 0.225) : neutral(0.16, 0.902),
      ink: dark ? neutral(0.18, 0.96) : neutral(0.28, 0.145),
      muted: dark ? neutral(0.08, 0.68) : neutral(0.09, 0.46),
      mutedStrong: dark ? neutral(0.10, 0.80) : neutral(0.12, 0.32),
      faint: dark ? neutral(0.06, 0.52) : neutral(0.08, 0.62),
      brand: brand,
      onBrand: onBrand,
      brandDark: dark ? scheme.primary : Color.lerp(brand, Colors.black, 0.24)!,
      brandSoft: scheme.primaryContainer,
      brandTint: dark ? neutral(0.22, 0.17) : neutral(0.32, 0.945),
      brandBorder: brand.withValues(alpha: dark ? 0.55 : 0.32),
      // Label colour on a solid brand hero panel, a light tint of the hue rather
      // than plain white so it sits comfortably on the fill. In dark mode the
      // fill is already light, so the on-colour is correct there.
      brandOnDark: dark ? scheme.onPrimary : Color.lerp(brand, Colors.white, 0.82)!,
      brandOnDarkMuted:
          dark ? scheme.onPrimary : Color.lerp(brand, Colors.white, 0.62)!,
      heroShadow: <BoxShadow>[
        BoxShadow(
          color: brand.withValues(alpha: dark ? 0.32 : 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      cardShadow: <BoxShadow>[
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.34)
              : const Color(0xFF163A36).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  /// Light tokens for the default brand colour. Used as a fallback so a widget
  /// built outside a themed subtree still has sensible colours.
  factory AppThemeTokens.fallback() => AppThemeTokens.from(
        ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        const Color(0xFF0F766E),
      );

  /// Reads the tokens from the ambient theme.
  ///
  /// Falls back to the default light tokens rather than throwing, so a widget
  /// placed outside a [MaterialApp] (a bare test pump, for example) still paints
  /// with the shipped palette.
  static AppThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<AppThemeTokens>() ?? AppThemeTokens.fallback();

  /// The seed colour the whole palette was derived from.
  final Color seed;
  final Brightness brightness;

  /// Page background behind the cards.
  final Color canvas;

  /// Card background.
  final Color surface;

  /// Recessed background, such as a read only field or a code block.
  final Color surfaceMuted;

  final Color border;

  /// Body and title text.
  final Color ink;

  /// Supporting copy.
  final Color muted;

  /// Emphasised supporting copy.
  final Color mutedStrong;

  /// Meta lines and disabled glyphs.
  final Color faint;

  /// The single brand colour: primary buttons, active icons, links, progress.
  final Color brand;

  /// Content that sits on top of [brand].
  final Color onBrand;

  /// A deeper shade of [brand], for pressed states and hero panel gradients.
  final Color brandDark;

  /// Low emphasis brand fill, such as a selected pill or a nav indicator.
  final Color brandSoft;

  /// The lightest brand wash, for a selected row inside a card.
  final Color brandTint;

  /// Hairline used to outline a selected control.
  final Color brandBorder;

  /// Label colour on a solid brand hero panel.
  final Color brandOnDark;

  /// Supporting label colour on a solid brand hero panel.
  final Color brandOnDarkMuted;

  final List<BoxShadow> heroShadow;
  final List<BoxShadow> cardShadow;

  bool get isDark => brightness == Brightness.dark;

  /// Picks black or white text for a swatch drawn in [background].
  ///
  /// The palette can be chosen by hand through the custom picker, so the
  /// checkmark on a swatch cannot rely on the brand tokens.
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.45 ? const Color(0xFF1D2B2A) : Colors.white;

  @override
  AppThemeTokens copyWith({
    Color? seed,
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? ink,
    Color? muted,
    Color? mutedStrong,
    Color? faint,
    Color? brand,
    Color? onBrand,
    Color? brandDark,
    Color? brandSoft,
    Color? brandTint,
    Color? brandBorder,
    Color? brandOnDark,
    Color? brandOnDarkMuted,
    List<BoxShadow>? heroShadow,
    List<BoxShadow>? cardShadow,
  }) {
    return AppThemeTokens(
      seed: seed ?? this.seed,
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      mutedStrong: mutedStrong ?? this.mutedStrong,
      faint: faint ?? this.faint,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandDark: brandDark ?? this.brandDark,
      brandSoft: brandSoft ?? this.brandSoft,
      brandTint: brandTint ?? this.brandTint,
      brandBorder: brandBorder ?? this.brandBorder,
      brandOnDark: brandOnDark ?? this.brandOnDark,
      brandOnDarkMuted: brandOnDarkMuted ?? this.brandOnDarkMuted,
      heroShadow: heroShadow ?? this.heroShadow,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return AppThemeTokens(
      seed: Color.lerp(seed, other.seed, t) ?? seed,
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedStrong: Color.lerp(mutedStrong, other.mutedStrong, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      brandBorder: Color.lerp(brandBorder, other.brandBorder, t)!,
      brandOnDark: Color.lerp(brandOnDark, other.brandOnDark, t)!,
      brandOnDarkMuted: Color.lerp(brandOnDarkMuted, other.brandOnDarkMuted, t)!,
      heroShadow: t < 0.5 ? heroShadow : other.heroShadow,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}