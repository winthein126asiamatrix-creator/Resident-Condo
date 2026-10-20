import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:test/core/utils/haptics.dart';

import '../../../../core/localization/app_locale_controller.dart';

import '../../../../core/theme/app_radius.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/sized_box_extensions.dart';

/// Bottom sheet for choosing the application language.
///
/// Extracted from the profile page so the picker owns its own presentation, the
/// same way the appearance feature owns [showAppColorPickerSheet]. It returns the
/// chosen language code, or null when the resident dismisses the sheet without
/// picking anything.
Future<String?> showLanguagePickerSheet(
  BuildContext context, {
  required AppLocaleController localeController,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => _LanguagePickerSheet(localeController: localeController),
  );
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.localeController});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final selectedCode = localeController.locale.languageCode;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          10,
          AppSpacing.gutter,
          AppSpacing.pageBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            AppSpacing.sectionGap.heightBox(),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: tokens.brand,
                    size: 22,
                  ),
                ),
                14.w.widthBox(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20.sp,
                          color: tokens.ink,
                        ),
                      ),
                      3.h.heightBox(),
                      Text(
                        'Choose the language the app is shown in',
                        style: TextStyle(color: tokens.muted, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.sectionGap.heightBox(),
            for (final code in AppLocaleController.supportedCodes)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: _LanguageOption(
                  code: code,
                  nativeName: localeController.displayName(code),
                  englishName: localeController.englishName(code),
                  isSelected: code == selectedCode,
                  onTap: () {
                    vibrateNow();
                    Navigator.of(context).pop(code);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final bool isSelected;
  final VoidCallback onTap;

  /// The badge letter used for a language, so each row is recognisable without
  /// shipping an emoji font. The first letter of the English name is used
  /// because it is guaranteed to be a single glyph in every locale.
  String get _badgeLetter => englishName.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Material(
      color: isSelected ? tokens.brandTint : tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () {
          vibrateNow();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? tokens.brandBorder : tokens.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              _Badge(letter: _badgeLetter, isSelected: isSelected),
              14.w.widthBox(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                        color: isSelected ? tokens.brandDark : tokens.ink,
                      ),
                    ),
                    2.h.heightBox(),
                    Text(
                      englishName,
                      style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              _TrailingIndicator(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.letter, required this.isSelected});

  final String letter;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? tokens.brand : tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17.sp,
          color: isSelected ? tokens.onBrand : tokens.mutedStrong,
        ),
      ),
    );
  }
}

class _TrailingIndicator extends StatelessWidget {
  const _TrailingIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? tokens.brand : Colors.transparent,
        border: Border.all(
          color: isSelected ? tokens.brand : tokens.border,
          width: 1.6,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, size: 16, color: tokens.onBrand)
          : null,
    );
  }
}
