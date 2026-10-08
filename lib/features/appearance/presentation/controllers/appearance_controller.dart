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
class AppearanceController extends GetxController {
  AppearanceController(this.useCases);

  final AppearanceUseCases useCases;

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

  Future<void> loadPreference() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final stored = await useCases.getPreference();
      saved.value = stored;
      draft.value = stored;
      customColorDraft.value = stored.seedColor;
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      // A storage read that fails must not stop the app from starting: the
      // resident keeps the default palette and can carry on using the app.
      errorMessage.value = 'Unable to load your appearance settings.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectPreset(AppColorSeed seed) {
    customColorDraft.value = seed.color;
    draft.value = draft.value.copyWith(seedColor: seed.color, presetId: seed.id);
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
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final stored = await useCases.savePreference(draft.value);
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

  /// Puts the live selection back to the shipped teal and System combination,
  /// and saves it straight away: a reset the resident could not see would be a
  /// trap.
  Future<bool> resetToDefault() async {
    final defaults = AppearancePreference.defaults();
    draft.value = defaults;
    customColorDraft.value = defaults.seedColor;
    return applyTheme();
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