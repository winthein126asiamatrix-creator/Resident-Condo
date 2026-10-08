import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/app_color_seed.dart';

/// The grid of circular colour swatches.
///
/// A swatch is a circle rather than a rounded square so the colour itself is
/// what the resident judges, with no corner to distort it. Selection is shown
/// three ways at once: a ring outside the colour, a gap between the ring and the
/// fill, and a tick inside. That keeps the choice readable without relying on
/// colour alone, and keeps it visible on a swatch picked through the custom
/// picker where no palette semantics apply.
///
/// Every cell is a full width target of 52px plus padding, comfortably over the
/// 48px platform minimum, and the grid reflows to four columns whatever the
/// screen width.
class AppColorSeedGrid extends StatelessWidget {
  const AppColorSeedGrid({
    required this.selected,
    required this.onSelected,
    required this.customColor,
    required this.isCustomSelected,
    required this.onCustomRequested,
    required this.selectionColor,
    super.key,
  });

  /// The preset currently selected, or null when a custom colour is in use.
  final AppColorSeed? selected;

  final ValueChanged<AppColorSeed> onSelected;

  /// The colour the Custom tile previews.
  final Color customColor;

  final bool isCustomSelected;

  final VoidCallback onCustomRequested;

  /// The colour the ring, tick and caption use on the selected swatch.
  ///
  /// Passed in rather than read from the theme because it is the colour being
  /// *previewed*: the ring around a swatch belongs to that choice, so it has to
  /// follow the draft rather than the palette the app is still running.
  final Color selectionColor;

  /// Four across on a phone, which keeps the tap target comfortably above the
  /// 48px guideline even on a 320px wide screen.
  static const _columns = 4;
  static const _spacing = AppSpacing.fieldGap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final seed in AppColorSeeds.all)
        _SeedCell(
          key: Key('appearance-seed-${seed.id}'),
          label: seed.name,
          color: seed.color,
          selected: seed.id == selected?.id,
          selectionColor: selectionColor,
          onTap: () => onSelected(seed),
        ),
      _CustomSeedCell(
        key: const Key('appearance-seed-custom'),
        color: customColor,
        selected: isCustomSelected,
        selectionColor: selectionColor,
        onTap: onCustomRequested,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = (width - _spacing * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: AppSpacing.fieldGap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// One palette entry: the circle, its name, and the tick.
class _SeedCell extends StatelessWidget {
  const _SeedCell({
    required this.label,
    required this.color,
    required this.selected,
    required this.selectionColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final Color selectionColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SeedButton(
      selected: selected,
      selectionColor: selectionColor,
      onTap: onTap,
      semanticsLabel: '$label app colour',
      // 52 keeps the whole tappable area at or above the platform minimum once
      // the padding around the circle is counted.
      swatch: _SwatchCircle(
        color: color,
        selected: selected,
        selectionColor: selectionColor,
      ),
      caption: label,
    );
  }
}

/// The trailing tile that opens the picker.
class _CustomSeedCell extends StatelessWidget {
  const _CustomSeedCell({
    required this.color,
    required this.selected,
    required this.selectionColor,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final Color selectionColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SeedButton(
      selected: selected,
      selectionColor: selectionColor,
      onTap: onTap,
      semanticsLabel: 'Custom app colour',
      swatch: _SwatchCircle.custom(
        color: color,
        selected: selected,
        selectionColor: selectionColor,
      ),
      caption: 'Custom',
    );
  }
}

/// Shared pressable wrapper: the ring, the circle and the caption all scale and
/// fade together, so selecting a colour reads as one motion.
class _SeedButton extends StatelessWidget {
  const _SeedButton({
    required this.selected,
    required this.selectionColor,
    required this.onTap,
    required this.semanticsLabel,
    required this.swatch,
    required this.caption,
  });

  final bool selected;
  final Color selectionColor;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Widget swatch;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  swatch,
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? selectionColor : AppPalette.muted,
                    ),
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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

/// The coloured circle itself.
///
/// The ring sits outside a transparent gap rather than directly on the fill, so
/// the swatch keeps its full size and the selection reads as a separate mark.
class _SwatchCircle extends StatelessWidget {
  const _SwatchCircle({
    required this.color,
    required this.selected,
    required this.selectionColor,
  }) : custom = false;

  const _SwatchCircle.custom({
    required this.color,
    required this.selected,
    required this.selectionColor,
  }) : custom = true;

  final Color color;
  final bool selected;

  /// The ring colour, which follows the swatch being previewed rather than the
  /// running theme.
  final Color selectionColor;

  /// The custom tile paints a faint checkerboard behind the colour, so a
  /// resident who picked a very pale shade can still see where the circle is.
  final bool custom;

  static const _size = 52.0;
  static const _ringWidth = 2.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Only the custom tile is outlined, so a very pale hand picked colour
        // still has a visible edge against the page.
        border: Border.all(
          color: custom ? scheme.outlineVariant : const Color(0x00000000),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_gap + _ringWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: selected ? _tick(color) : null,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _size + _ringWidth * 2 + _gap * 2,
      height: _size + _ringWidth * 2 + _gap * 2,
      padding: const EdgeInsets.all(_ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Transparent when unselected, so the ring does not shrink the colour
        // or add a border that was not asked for.
        border: Border.all(
          color: selected ? selectionColor : const Color(0x00000000),
          width: _ringWidth,
        ),
      ),
      child: circle,
    );
  }

  Widget _tick(Color fill) {
    // Chosen from the fill rather than the theme: an amber or lime swatch needs
    // dark ink on it to stay legible.
    final foreground = fill.computeLuminance() > 0.45
        ? AppPalette.ink
        : Colors.white;
    return Center(
      child: Icon(Icons.check_rounded, size: 22, color: foreground),
    );
  }
}

/// Section copy used above the palette. Kept here so the page reads top down
/// without the strings drifting between the two.
abstract final class AppAppearanceCopy {
  static const title = 'Choose your app color';
  static const description =
      'Select a color that feels right for you. Your choice will be used '
      'throughout the app.';

  static const previewTitle = 'Preview';
  static const previewDescription =
      'A live look at your home screen with the color you picked.';
}