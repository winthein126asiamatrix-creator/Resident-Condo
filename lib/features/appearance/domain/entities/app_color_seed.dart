import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// The brand colours a resident can pick, plus the option to define their own.
///
/// Seeds are chosen so `ColorScheme.fromSeed` produces a usable tonal palette
/// for each one: every seed is a mid tone, which keeps the generated primary
/// readable against white and lets the on-colour flip in dark mode. A very light
/// seed such as a pale yellow would generate a primary no text can sit on.
@immutable
class AppColorSeed {
  const AppColorSeed({
    required this.id,
    required this.name,
    required this.color,
  });

  /// Stable id, so the saved preference survives a reordering of the palette.
  final String id;
  final String name;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is AppColorSeed && other.id == id && other.color == color;

  @override
  int get hashCode => Object.hash(id, color);
}

/// The palette offered on the Appearance screen.
abstract final class AppColorSeeds {
  static const List<AppColorSeed> all = <AppColorSeed>[
    AppColorSeed(id: 'blue', name: 'Blue', color: Color(0xFF2563EB)),
    AppColorSeed(id: 'sky', name: 'Sky', color: Color(0xFF0EA5E9)),
    AppColorSeed(id: 'teal', name: 'Teal', color: Color(0xFF0F766E)),
    AppColorSeed(id: 'cyan', name: 'Cyan', color: Color(0xFF0891B2)),
    AppColorSeed(id: 'green', name: 'Green', color: Color(0xFF16A34A)),
    AppColorSeed(id: 'emerald', name: 'Emerald', color: Color(0xFF059669)),
    AppColorSeed(id: 'lime', name: 'Lime', color: Color(0xFF4D7C0F)),
    AppColorSeed(id: 'orange', name: 'Orange', color: Color(0xFFEA580C)),
    AppColorSeed(id: 'amber', name: 'Amber', color: Color(0xFFD97706)),
    AppColorSeed(id: 'red', name: 'Red', color: Color(0xFFDC2626)),
    AppColorSeed(id: 'pink', name: 'Pink', color: Color(0xFFDB2777)),
    AppColorSeed(id: 'purple', name: 'Purple', color: Color(0xFF9333EA)),
    AppColorSeed(id: 'indigo', name: 'Indigo', color: Color(0xFF4F46E5)),
    AppColorSeed(id: 'violet', name: 'Violet', color: Color(0xFF7C3AED)),
    AppColorSeed(id: 'slate', name: 'Slate', color: Color(0xFF475569)),
  ];

  /// The shipped brand colour, offered as a preset so "Reset to Default" and
  /// picking Teal by hand land on exactly the same theme.
  static const AppColorSeed defaultSeed = AppColorSeed(
    id: 'teal',
    name: 'Teal',
    color: AppPalette.brand,
  );

  static AppColorSeed? byId(String id) {
    for (final seed in all) {
      if (seed.id == id) {
        return seed;
      }
    }
    return null;
  }
}

/// Which appearance the app renders with.
enum AppBrightnessMode {
  light('light', 'Light'),
  dark('dark', 'Dark'),
  system('system', 'System');

  const AppBrightnessMode(this.id, this.label);

  final String id;
  final String label;

  /// Short line explaining what the mode does, shown under the control.
  String get description => switch (this) {
        AppBrightnessMode.light => 'Always the light palette',
        AppBrightnessMode.dark => 'Always the dark palette',
        AppBrightnessMode.system => 'Follows your phone setting',
      };

  /// Resolves the mode against the platform brightness.
  Brightness resolve(Brightness platformBrightness) => switch (this) {
        AppBrightnessMode.light => Brightness.light,
        AppBrightnessMode.dark => Brightness.dark,
        AppBrightnessMode.system => platformBrightness,
      };

  /// How a [GetMaterialApp] should be told to pick between the light and dark
  /// palettes. System has to map to `ThemeMode.system` rather than to a
  /// resolved brightness, otherwise the app would stop following the phone while
  /// the resident is in a different room.
  ThemeMode get themeMode => switch (this) {
        AppBrightnessMode.light => ThemeMode.light,
        AppBrightnessMode.dark => ThemeMode.dark,
        AppBrightnessMode.system => ThemeMode.system,
      };

  static AppBrightnessMode byId(String id) {
    for (final mode in AppBrightnessMode.values) {
      if (mode.id == id) {
        return mode;
      }
    }
    return AppBrightnessMode.system;
  }
}