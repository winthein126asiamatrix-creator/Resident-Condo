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
/// This controller is the single source of truth for the brand colour. The root
/// [GetMaterialApp] reads [draft] to build its `ThemeData`, so a change here
/// rebuilds the theme for every mounted screen at once, with no navigation and
/// no restart.
///
/// Two values are kept, and the difference matters:
///
/// * [draft] is what the resident is looking at *now*. Selecting a swatch
///   updates it, which repaints the whole app immediately.
/// * [saved] is what is on disk. Only [applyTheme] writes it.
///
/// So "Apply Theme" is the save, and everything before it is live. That keeps
/// the instant feedback and makes the persistence explicit rather than hidden.
class AppearanceController extends GetxController {
  AppearanceController(this.useCases);

  final AppearanceUseCases useCases;

  /// The live selection. Drives the whole application theme.
  final draft = AppearancePreference.defaults().obs;

  /// The preference currently on disk.
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

  /// True while the live selection differs from what is stored, which is what
  /// enables "Apply Theme" and shows the unsaved chip.
  bool get hasUnsavedChanges => draft.value != saved.value;

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

  /// Writes the live selection to storage. Returns whether it stuck.
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

  /// The theme the application should currently be rendering with.
  ThemeData get theme =>
      AppTheme.forSeed(draft.value.seedColor, Brightness.light);

  /// The dark counterpart, so `ThemeMode.system` and `ThemeMode.dark` have
  /// something to resolve against.
  ThemeData get darkTheme =>
      AppTheme.forSeed(draft.value.seedColor, Brightness.dark);

  ThemeMode get themeMode => draft.value.brightnessMode.themeMode;

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