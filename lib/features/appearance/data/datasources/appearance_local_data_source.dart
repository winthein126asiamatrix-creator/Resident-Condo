import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_color_seed.dart';
import '../../domain/entities/appearance_preference.dart';

/// Persists the resident's appearance across launches.
///
/// Every preference is keyed by the authenticated user's id, so signing in as a
/// different resident on the same device never inherits the previous one's
/// colour. The seed colour is stored as its ARGB integer and the preset id
/// alongside it, so a preset stays a named preset after a restart while a colour
/// chosen through the custom picker round trips exactly. The brightness mode is
/// stored as its id string for the same reason.
///
/// The active user id is remembered on its own so the last applied theme can be
/// painted immediately on the next launch, before `/auth/me` has answered.
///
/// Tests pass a [SharedPreferences] primed with `setMockInitialValues`, so no
/// platform channel is involved.
class AppearanceLocalDataSource {
  AppearanceLocalDataSource([SharedPreferences? preferences])
    : _preferences = preferences;

  static const _activeAccountKey = 'appearance.active_account_id';

  static String _seedKey(String accountId) =>
      'appearance.$accountId.seed_color';
  static String _presetKey(String accountId) =>
      'appearance.$accountId.preset_id';
  static String _modeKey(String accountId) =>
      'appearance.$accountId.brightness_mode';
  static String _pendingSyncKey(String accountId) =>
      'appearance.$accountId.pending_sync';

  final SharedPreferences? _preferences;

  SharedPreferences? _resolved;

  /// Resolved on first use rather than in the constructor, because
  /// `SharedPreferences.getInstance` is async and the project's dependency
  /// injection is synchronous.
  Future<SharedPreferences> get _store async =>
      _resolved ??= _preferences ?? await SharedPreferences.getInstance();

  /// The user whose theme was last applied, or null after a sign-out.
  Future<String?> getActiveAccountId() async =>
      (await _store).getString(_activeAccountKey);

  Future<void> setActiveAccount(String accountId) async {
    await (await _store).setString(_activeAccountKey, accountId);
  }

  Future<void> clearActiveAccount() async {
    await (await _store).remove(_activeAccountKey);
  }

  /// This user's saved preference, or null when they have never chosen one.
  ///
  /// A corrupt entry reads as "nothing stored" rather than throwing, so a bad
  /// value can never stop the app from starting.
  Future<AppearancePreference?> getPreference(String accountId) async {
    final preferences = await _store;
    final seed = preferences.getInt(_seedKey(accountId));
    if (seed == null) {
      return null;
    }
    return AppearancePreference(
      seedColor: Color(seed),
      presetId: preferences.getString(_presetKey(accountId)),
      brightnessMode: AppBrightnessMode.byId(
        preferences.getString(_modeKey(accountId)) ?? '',
      ),
    );
  }

  /// Whether this user has a local change the backend has not accepted yet.
  Future<bool> hasPendingSync(String accountId) async =>
      (await _store).getBool(_pendingSyncKey(accountId)) ?? false;

  Future<AppearancePreference> savePreference(
    String accountId,
    AppearancePreference preference, {
    bool markPendingSync = false,
  }) async {
    final preferences = await _store;
    await preferences.setInt(
      _seedKey(accountId),
      preference.seedColor.toARGB32(),
    );
    final presetId = preference.presetId;
    if (presetId == null) {
      // A hand picked colour has no preset, so the stale name from a previous
      // choice must not survive and relabel it.
      await preferences.remove(_presetKey(accountId));
    } else {
      await preferences.setString(_presetKey(accountId), presetId);
    }
    await preferences.setString(
      _modeKey(accountId),
      preference.brightnessMode.id,
    );
    await preferences.setBool(_pendingSyncKey(accountId), markPendingSync);
    await setActiveAccount(accountId);
    return preference;
  }

  /// Removes this user's appearance only, leaving every other setting and every
  /// other account's cache untouched.
  Future<AppearancePreference> resetPreference(String accountId) async {
    final preferences = await _store;
    await preferences.remove(_seedKey(accountId));
    await preferences.remove(_presetKey(accountId));
    await preferences.remove(_modeKey(accountId));
    await preferences.remove(_pendingSyncKey(accountId));
    return AppearancePreference.defaults();
  }
}
