import 'package:flutter/material.dart';

import '../../domain/entities/app_color_seed.dart';

/// A resident's saved appearance: one brand seed plus a brightness mode.
///
/// The colour is held as a [Color] rather than a preset id, so a value chosen
/// through the custom picker round trips exactly, with no lookup in
/// [AppColorSeeds].
@immutable
class AppearancePreference {
  const AppearancePreference({
    required this.seedColor,
    required this.brightnessMode,
    this.presetId,
  });

  /// The brand colour in use.
  final Color seedColor;

  /// The preset this colour came from, or null when it was chosen by hand.
  final String? presetId;

  final AppBrightnessMode brightnessMode;

  /// What the app looked like before Appearance existed: the original teal,
  /// following the system brightness.
  factory AppearancePreference.defaults() => AppearancePreference(
        seedColor: AppColorSeeds.defaultSeed.color,
        presetId: AppColorSeeds.defaultSeed.id,
        brightnessMode: AppBrightnessMode.system,
      );

  /// The preset matching this preference, or null for a custom colour.
  AppColorSeed? get preset =>
      presetId == null ? null : AppColorSeeds.byId(presetId!);

  bool get isCustomColor => presetId == null;

  /// The label shown under the swatch grid: the preset name, or the hex value
  /// of a custom colour.
  String get label {
    final match = preset;
    if (match != null) {
      return match.name;
    }
    return hexLabel;
  }

  /// Uppercase `#RRGGBB`, the form residents recognise from design tools.
  String get hexLabel =>
      '#${seedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  AppearancePreference copyWith({
    Color? seedColor,
    String? presetId,
    bool clearPreset = false,
    AppBrightnessMode? brightnessMode,
  }) {
    return AppearancePreference(
      seedColor: seedColor ?? this.seedColor,
      presetId: clearPreset ? null : (presetId ?? this.presetId),
      brightnessMode: brightnessMode ?? this.brightnessMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppearancePreference &&
      other.seedColor == seedColor &&
      other.presetId == presetId &&
      other.brightnessMode == brightnessMode;

  @override
  int get hashCode => Object.hash(seedColor, presetId, brightnessMode);
}