import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_color_seed.dart';
import '../../domain/entities/appearance_preference.dart';

/// Persists the resident's appearance across launches.
///
/// The seed colour is stored as its ARGB integer and the preset id alongside
/// it, so a preset stays a named preset after a restart while a colour chosen
/// through the custom picker round trips exactly. The brightness mode is stored
/// as its id string for the same reason.
///
/// Tests pass a [SharedPreferences] primed with `setMockInitialValues`, so no
/// platform channel is involved.
class AppearanceLocalDataSource {
  AppearanceLocalDataSource([SharedPreferences? preferences])
      : _preferences = preferences;

  static const _seedKey = 'appearance.seed_color';
  static const _presetKey = 'appearance.preset_id';
  static const _modeKey = 'appearance.brightness_mode';

  final SharedPreferences? _preferences;

  SharedPreferences? _resolved;

  /// Resolved on first use rather than in the constructor, because
  /// `SharedPreferences.getInstance` is async and the project's dependency
  /// injection is synchronous.
  Future<SharedPreferences> get _store async =>
      _resolved ??= _preferences ?? await SharedPreferences.getInstance();

  /// The saved preference, or the shipped default when nothing is stored or the
  /// stored values are unreadable. A corrupt entry must never stop the app from
  /// starting, so it falls back rather than throwing.
  Future<AppearancePreference> getPreference() async {
    final preferences = await _store;
    final seed = preferences.getInt(_seedKey);
    if (seed == null) {
      return AppearancePreference.defaults();
    }
    return AppearancePreference(
      seedColor: Color(seed),
      presetId: preferences.getString(_presetKey),
      brightnessMode: AppBrightnessMode.byId(
        preferences.getString(_modeKey) ?? '',
      ),
    );
  }

  Future<AppearancePreference> savePreference(
    AppearancePreference preference,
  ) async {
    final preferences = await _store;
    await preferences.setInt(_seedKey, preference.seedColor.toARGB32());
    final presetId = preference.presetId;
    if (presetId == null) {
      // A hand picked colour has no preset, so the stale name from a previous
      // choice must not survive and relabel it.
      await preferences.remove(_presetKey);
    } else {
      await preferences.setString(_presetKey, presetId);
    }
    await preferences.setString(_modeKey, preference.brightnessMode.id);
    return preference;
  }

  Future<AppearancePreference> resetPreference() async {
    final preferences = await _store;
    await preferences.remove(_seedKey);
    await preferences.remove(_presetKey);
    await preferences.remove(_modeKey);
    return AppearancePreference.defaults();
  }
}