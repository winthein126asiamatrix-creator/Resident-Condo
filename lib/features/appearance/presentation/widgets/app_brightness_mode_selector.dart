import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../domain/entities/app_color_seed.dart';

/// Light / Dark / System, as three equal options rather than a switch.
///
/// A two state switch cannot express "follow my phone", which is the setting
/// most residents actually want, so the third option is given the same weight as
/// the other two.
///
/// Each option carries a small illustration of the palette it selects rather
/// than only an icon, which is what makes the choice obvious at a glance.
class AppBrightnessModeSelector extends StatelessWidget {
  const AppBrightnessModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AppBrightnessMode value;
  final ValueChanged<AppBrightnessMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // A fixed height so the three options stay the same size whatever the text
    // scale, and so the control below them never shifts.
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        for (final mode in AppBrightnessMode.values) ...[
            Expanded(
              child: _ModeOption(
                key: Key('appearance-mode-${mode.id}'),
                mode: mode,
                selected: mode == value,
                onTap: () => onChanged(mode),
              ),
            ),
            if (mode != AppBrightnessMode.values.last)
              const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppBrightnessMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final radius = BorderRadius.circular(AppRadius.xl);

    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} appearance, ${mode.description.toLowerCase()}',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? tokens.brandTint : tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? tokens.brand : tokens.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModeIllustration(mode: mode, selected: selected),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected ? tokens.brand : tokens.ink,
                          ),
                        ),
                      ),
                      // A tick alongside the tint and the border, so the choice
                      // is not signalled by colour alone.
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: selected ? 1 : 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: tokens.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: selected ? tokens.brand : tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature split of the palette each mode produces.
///
/// Two swatches on a light ground for Light, the inverse for Dark, and both for
/// System, which is exactly the distinction the label is describing.
class _ModeIllustration extends StatelessWidget {
  const _ModeIllustration({required this.mode, required this.selected});

  final AppBrightnessMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isSystem = mode == AppBrightnessMode.system;

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          _Half(
            background: isSystem || mode == AppBrightnessMode.light
                ? const Color(0xFFF4F7F6)
                : const Color(0xFF16201F),
            foreground: isSystem || mode == AppBrightnessMode.light
                ? tokens.brand
                : tokens.brand,
            radius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          _Half(
            background: isSystem || mode == AppBrightnessMode.dark
                ? const Color(0xFF16201F)
                : const Color(0xFFF4F7F6),
            foreground: tokens.brand,
            radius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.background,
    required this.foreground,
    required this.radius,
  });

  final Color background;
  final Color foreground;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Expanded(
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: tokens.border),
        ),
        // A dot rather than a bar, so it reads as a colour sample.
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

