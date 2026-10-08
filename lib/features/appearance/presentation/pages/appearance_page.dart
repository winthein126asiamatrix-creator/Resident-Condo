import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/appearance_preference.dart';
import '../controllers/appearance_controller.dart';
import '../widgets/app_appearance_preview_card.dart';
import '../widgets/app_brightness_mode_selector.dart';
import '../widgets/app_color_picker_sheet.dart';
import '../widgets/app_color_seed_grid.dart';

/// The Appearance screen.
///
/// Deliberately one scroll view with a sticky action bar: everything here is a
/// decision about the same thing, so splitting it across pages would make the
/// resident lose the preview exactly when they need it.
///
/// The preview sits above the action bar and follows the draft, not the saved
/// preference, so the effect of a colour is visible before it is committed.
class AppearancePage extends GetView<AppearanceController> {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppDetailAppBar(
        title: 'Appearance',
        subtitle: 'Personalize your app experience',
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        // An error only takes over the screen when there is nothing to show.
        // A failure to re-read storage while the resident is editing should not
        // wipe the palette they are looking at.
        if (controller.errorMessage.value != null &&
            controller.isLoading.value == false &&
            controller.hasUnsavedChanges == false &&
            controller.draft.value == AppearancePreference.defaults()) {
          return AppStateMessage(
            title: 'Unable to load appearance',
            message: controller.errorMessage.value!,
            icon: Icons.palette_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadPreference,
          );
        }
        return _Body(controller: controller);
      }),
      bottomNavigationBar: const _AppearanceActionBar(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final AppearanceController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return ListView(
      key: const Key('appearance-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.pageTop,
        AppSpacing.gutter,
        AppSpacing.pageBottom,
      ),
      children: [
        Text(
          AppAppearanceCopy.title,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        Text(
          AppAppearanceCopy.description,
          style: TextStyle(
            color: tokens.muted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const AppSectionHeader(title: 'App color'),
        const SizedBox(height: AppSpacing.cardGap + 4),
        Obx(
          () => AppColorSeedGrid(
            selected: controller.draft.value.preset,
            onSelected: controller.selectPreset,
            customColor: controller.draft.value.seedColor,
            isCustomSelected: controller.draft.value.isCustomColor,
            onCustomRequested: () => _openColorPicker(context, controller),
            // The ring and caption follow the colour being tried, not the one
            // the app is still running.
            selectionColor: controller.draft.value.seedColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        AppSectionHeader(
          title: 'Appearance',
          actionLabel: 'Reset to Default',
          onAction: () => _reset(context, controller),
        ),
        const SizedBox(height: 4),
        Text(
          'Light, dark, or follow your phone setting.',
          style: TextStyle(color: tokens.muted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.fieldGap + 2),
        Obx(
          () => AppBrightnessModeSelector(
            value: controller.draft.value.brightnessMode,
            onChanged: controller.selectBrightnessMode,
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap + 4),
        Text(
          AppAppearanceCopy.previewTitle,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        Text(
          AppAppearanceCopy.previewDescription,
          style: TextStyle(color: tokens.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.cardGap + 4),
        // The preview is wrapped in its own Theme so it paints with the draft
        // tokens. The surrounding screen keeps the applied theme, which is what
        // makes the contrast between the two readable: the resident sees the new
        // palette inside the frame and the old one around it.
        Obx(
          () => _PreviewSurface(
            controller: controller,
            child: AppAppearancePreviewCard(
              tokens: controller.previewTokens,
              greeting: 'Good morning, Mary',
              unitLabel: 'Building A · Unit A-101',
              balanceAmount: '\$100',
              balanceDue: 'Due Sep 30',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openColorPicker(
    BuildContext context,
    AppearanceController controller,
  ) async {
    final picked = await showAppColorPickerSheet(
      context,
      initial: controller.draft.value.seedColor,
      // The preview follows the drag, so the resident never has to commit to a
      // shade to find out whether they like it.
      onChanged: controller.previewCustomColor,
    );
    if (picked == null) {
      return;
    }
    controller.commitCustomColor(picked);
  }

  Future<void> _reset(
    BuildContext context,
    AppearanceController controller,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Reset appearance?',
      message:
          'Your app color returns to the original Condo Residents teal and '
          'follows your phone setting.',
      confirmLabel: 'Reset',
    );
    if (!confirmed) {
      return;
    }
    final applied = await controller.resetToDefault();
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: applied ? 'Appearance reset' : 'Could not reset',
      message: applied
          ? 'The default teal theme is back.'
          : 'Please try again.',
      isError: !applied,
    );
  }
}

/// Wraps the preview in a [Theme] built from the draft tokens, and paints a
/// hairline frame around it so it reads as a device screen on the page.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.controller, required this.child});

  final AppearanceController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = controller.previewTokens;
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: controller.draft.value.seedColor,
          brightness: controller.previewBrightness,
        ),
        extensions: <ThemeExtension<dynamic>>[tokens],
      ),
      child: child,
    );
  }
}

/// The sticky footer: the commit action, plus the currently applied colour named
/// back to the resident so they always know what the app is using right now.
class _AppearanceActionBar extends StatelessWidget {
  const _AppearanceActionBar();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        12,
        AppSpacing.gutter,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: tokens.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final controller = Get.find<AppearanceController>();
          final draft = controller.draft.value;
          final changed = controller.hasUnsavedChanges;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _CurrentSwatch(color: draft.seedColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          changed ? 'Not applied yet' : 'Applied',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: changed ? tokens.brand : tokens.muted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${draft.label} · ${draft.brightnessMode.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppPrimaryAction(
                key: const Key('appearance-apply'),
                onPressed: changed
                    ? () => _apply(context, controller)
                    : null,
                isLoading: controller.isSaving.value,
                label: 'Apply Theme',
                icon: Icons.check_rounded,
                backgroundColor: draft.seedColor,
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _apply(
    BuildContext context,
    AppearanceController controller,
  ) async {
    final applied = await controller.applyTheme();
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: applied ? 'Theme applied' : 'Could not apply theme',
      message: applied
          ? 'The app now uses ${controller.saved.value.label}.'
          : 'Please try again.',
      isError: !applied,
    );
  }
}

class _CurrentSwatch extends StatelessWidget {
  const _CurrentSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
    );
  }
}