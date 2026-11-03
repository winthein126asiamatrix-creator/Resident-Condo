import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../domain/entities/app_color_seed.dart';
import '../../domain/entities/appearance_preference.dart';
import '../../domain/usecases/appearance_usecases.dart';

/// The one place the app's colour lives.
///
/// This controller is the single source of truth for the brand colour, and it
/// keeps two values on purpose:
///
/// * [draft] is the *preview*: the colour the resident is trying on the
///   Appearance screen. Selecting a swatch or dragging the custom picker
///   updates it, and only the preview follows.
/// * [saved] is the *applied* theme: what the whole app is actually rendering
///   with and what is written to storage. Only [applyTheme] moves it.
///
/// The root [GetMaterialApp] builds its `ThemeData` from [saved], so tapping a
/// colour never repaints another screen by accident. "Apply Theme" is the only
/// path from preview to applied, and it persists in the same step.
///
/// Preferences are scoped to the authenticated user's id. A valid `theme_color`
/// from `/auth/me` is the source of truth and replaces the cached local colour;
/// a missing or invalid value falls back to the user's cache, then the default.
class AppearanceController extends GetxController {
  AppearanceController(this.useCases);

  final AppearanceUseCases useCases;

  /// The authenticated user whose preference is loaded, or null when nobody is
  /// signed in.
  String? _accountId;

  /// Guards async loads against each other, so a slow read for a previous user
  /// cannot land after a newer sign-in and paint the wrong theme.
  int _loadVersion = 0;

  /// The colour being previewed on the Appearance screen.
  final draft = AppearancePreference.defaults().obs;

  /// The applied theme: what the app renders with and what is on disk.
  final saved = AppearancePreference.defaults().obs;

  /// The colour the custom picker is editing.
  final customColorDraft = AppColorSeeds.defaultSeed.color.obs;

  final isLoading = true.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadPreference();
  }

  /// True while the preview differs from the applied theme, which is what
  /// enables "Apply Theme" and shows the unsaved chip.
  bool get hasUnsavedChanges => draft.value != saved.value;

  /// The colour currently shown in the preview.
  Color get previewThemeColor => draft.value.seedColor;

  /// The colour the whole app is actually rendering with.
  Color get appliedThemeColor => saved.value.seedColor;

  /// Starts a preview session.
  ///
  /// Called when the Appearance screen opens, so the preview always begins
  /// from the applied theme rather than from whatever a previous visit left
  /// behind.
  void startPreview() {
    draft.value = saved.value;
    customColorDraft.value = saved.value.seedColor;
  }

  /// Ends a preview session without applying.
  ///
  /// Called when the Appearance screen is left, so a colour that was only
  /// being tried cannot leak into the next visit's preview.
  void discardPreview() {
    draft.value = saved.value;
    customColorDraft.value = saved.value.seedColor;
  }

  /// True once the resident has moved away from the shipped default, so
  /// "Reset to Default" only appears when it would do something.
  bool get canReset => draft.value != AppearancePreference.defaults();

  /// Restores the last active user's theme, or the shipped default when there
  /// is none. This is what paints the first frame before `/auth/me` answers.
  Future<void> loadPreference() async {
    final version = ++_loadVersion;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final activeAccountId = await useCases.getActiveAccountId();
      final accountId = _accountId ?? activeAccountId;
      _accountId = accountId;
      final stored = accountId == null
          ? null
          : await useCases.getPreference(accountId);
      if (version != _loadVersion) {
        return;
      }
      _apply(stored ?? AppearancePreference.defaults());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      // A storage read that fails must not stop the app from starting: the
      // resident keeps the default palette and can carry on using the app.
      errorMessage.value = 'Unable to load your appearance settings.';
    } finally {
      if (version == _loadVersion) {
        isLoading.value = false;
      }
    }
  }

  /// Applies `/auth/me`'s theme for [accountId].
  ///
  /// Precedence is deliberate:
  ///
  /// * A valid backend `theme_color` always wins, and is written over the local
  ///   cache so a stale colour cannot survive the next launch.
  /// * When the backend value is missing or invalid, the user's cached
  ///   preference is used, then the shipped default.
  ///
  /// A colour chosen on the Appearance screen is applied and cached immediately,
  /// then reasserted by the backend on the next successful `/auth/me`, which is
  /// the source of truth once the session is validated.
  ///
  /// Never throws: appearance must not turn a successful sign-in into a failed
  /// one.
  Future<void> applyAuthenticatedUser({
    required String accountId,
    String? backendThemeColor,
  }) async {
    final version = ++_loadVersion;
    _accountId = accountId;
    errorMessage.value = null;
    try {
      final backendColor = AppColorSeeds.colorFromHex(backendThemeColor);
      final local = await useCases.getPreference(accountId);

      var preference = local ?? AppearancePreference.defaults();
      if (backendColor != null) {
        final preset = AppColorSeeds.byColor(backendColor);
        preference = preference.copyWith(
          seedColor: backendColor,
          presetId: preset?.id,
          clearPreset: preset == null,
        );
        await useCases.savePreference(
          accountId,
          preference,
          markPendingSync: false,
        );
      }

      await useCases.setActiveAccount(accountId);
      if (version != _loadVersion) {
        return;
      }
      _apply(preference);
    } catch (_) {
      // Keep the current theme; a preference is not a reason to block access.
    } finally {
      if (version == _loadVersion) {
        isLoading.value = false;
      }
    }
  }

  /// Returns the app to the shipped default and forgets the active user.
  ///
  /// Per-user preferences are deliberately left on disk: signing the same user
  /// back in restores their colour, while another user still reads only their
  /// own keys because every preference is account-scoped.
  Future<void> onSignedOut() async {
    ++_loadVersion;
    _accountId = null;
    errorMessage.value = null;
    isLoading.value = false;
    _apply(AppearancePreference.defaults());
    try {
      await useCases.clearActiveAccount();
    } catch (_) {
      // Signing out must finish even if the local marker cannot be cleared.
    }
  }

  void selectPreset(AppColorSeed seed) {
    customColorDraft.value = seed.color;
    draft.value = draft.value.copyWith(
      seedColor: seed.color,
      presetId: seed.id,
    );
  }

  /// Picks the colour the custom picker is editing, without persisting it. The
  /// app follows along so the resident can dial a shade in.
  void previewCustomColor(Color color) {
    customColorDraft.value = color;
    draft.value = draft.value.copyWith(seedColor: color, clearPreset: true);
  }

  /// Commits the picker's colour to the live selection.
  void commitCustomColor(Color color) {
    customColorDraft.value = color;
    draft.value = draft.value.copyWith(seedColor: color, clearPreset: true);
  }

  void selectBrightnessMode(AppBrightnessMode mode) {
    draft.value = draft.value.copyWith(brightnessMode: mode);
  }

  /// The one path from preview to applied.
  ///
  /// Writes the previewed preference to storage, which also makes it the
  /// applied theme: [saved] changes, the root `GetMaterialApp` rebuilds, and
  /// every mounted screen picks the new colour up at once. Returns whether the
  /// write stuck.
  Future<bool> applyTheme() async {
    final accountId = await _currentAccountId();
    if (accountId == null) {
      errorMessage.value = 'No signed-in resident for this appearance change.';
      return false;
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      final stored = await useCases.savePreference(
        accountId,
        draft.value,
        markPendingSync: true,
      );
      saved.value = stored;
      return true;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Unable to apply the theme.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<String?> _currentAccountId() async {
    final known = _accountId;
    if (known != null) {
      return known;
    }
    final active = await useCases.getActiveAccountId();
    _accountId = active;
    return active;
  }

  /// Puts the live selection back to the shipped blue and System combination,
  /// and saves it straight away: a reset the resident could not see would be a
  /// trap.
  Future<bool> resetToDefault() async {
    final defaults = AppearancePreference.defaults();
    draft.value = defaults;
    customColorDraft.value = defaults.seedColor;
    return applyTheme();
  }

  void _apply(AppearancePreference preference) {
    saved.value = preference;
    draft.value = preference;
    customColorDraft.value = preference.seedColor;
  }

  /// The brightness the preview renders at, with System resolved against the
  /// device setting so tapping System visibly changes the preview.
  Brightness get previewBrightness =>
      draft.value.brightnessMode.resolve(currentPlatformBrightness());

  /// The theme the application is actually rendering with.
  ///
  /// Built from [saved] — the applied preference — never from [draft]. That is
  /// what keeps a previewed colour contained to the Appearance screen until it
  /// is applied.
  ThemeData get theme =>
      AppTheme.forSeed(saved.value.seedColor, Brightness.light);

  /// The dark counterpart, so `ThemeMode.system` and `ThemeMode.dark` have
  /// something to resolve against.
  ThemeData get darkTheme =>
      AppTheme.forSeed(saved.value.seedColor, Brightness.dark);

  ThemeMode get themeMode => saved.value.brightnessMode.themeMode;

  /// The device's own brightness setting, which is what System mode follows.
  ///
  /// Read from the platform dispatcher rather than a `MediaQuery` because this
  /// is read outside the widget tree, and the controller is constructed before
  /// any context exists.
  static Brightness currentPlatformBrightness() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  /// The tokens the preview paints with, so the mini app on the screen matches
  /// what the app itself is rendering.
  AppThemeTokens get previewTokens => AppThemeTokens.from(
    AppTheme.schemeFor(draft.value.seedColor, previewBrightness),
    draft.value.seedColor,
  );
}
