import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_theme_tokens.dart';

/// One segment of a [AppSegmentedTabs] strip.
@immutable
class AppSegmentedTab {
  const AppSegmentedTab({
    required this.name,
    required this.label,
    required this.icon,
  });

  /// Stable id, used for the segment's key and never shown to the resident.
  final String name;

  final String label;
  final IconData icon;
}

/// The pill strip the store, condo services and rules use to move between
/// sections of a screen.
///
/// A single white pill slides along the track instead of separate boxes fading
/// in and out, and it dips under the finger on the way in. When the screen is
/// backed by a [PageView], pass its controller and the pill is read from the
/// page itself, so the highlight and the content always arrive together.
///
/// This navigates between sections. To pick one option inside a form, use
/// [AppSegmentedControl] instead, which shows every option at once.
class AppSegmentedTabs extends StatefulWidget {
  const AppSegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    required this.keyPrefix,
    this.pages,
    super.key,
  });

  final List<AppSegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Names the segment keys, so a screen keeps its own test hooks.
  final String keyPrefix;

  /// The page view behind the strip, when the screen has one.
  final PageController? pages;

  /// One slide, shared with the content that moves alongside the strip.
  static const slideDuration = Duration(milliseconds: 280);
  static const slideCurve = Curves.easeOutCubic;

  @override
  State<AppSegmentedTabs> createState() => _AppSegmentedTabsState();
}

class _AppSegmentedTabsState extends State<AppSegmentedTabs>
    with SingleTickerProviderStateMixin {
  /// Where the pill sits, in tab units, for a screen with no page view to read.
  /// A whole number is a resting tab and a fraction is one caught mid slide.
  /// Created on demand, so a screen driven by a page view never builds it.
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: AppSegmentedTabs.slideDuration,
    value: widget.selectedIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant AppSegmentedTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages != null ||
        oldWidget.selectedIndex == widget.selectedIndex) {
      return;
    }
    _position.animateTo(
      widget.selectedIndex.toDouble(),
      curve: AppSegmentedTabs.slideCurve,
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  /// A page view that has not been laid out yet cannot say where it is, so the
  /// strip falls back to the selection it was built with.
  double get _value {
    final pages = widget.pages;
    if (pages == null) {
      return _position.value;
    }
    final last = (widget.tabs.length - 1).toDouble();
    if (!pages.hasClients) {
      return widget.selectedIndex.toDouble().clamp(0.0, last);
    }
    return (pages.page ?? widget.selectedIndex.toDouble()).clamp(0.0, last);
  }

  /// True while the pill is closer to [index] than to either neighbour, which is
  /// what decides the label colours halfway through a slide.
  bool _isSelected(double position, int index) =>
      (position - index).abs() < 0.5;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    return LayoutBuilder(
      builder: (context, constraints) {
        const inset = 4.0;
        final segmentWidth = (constraints.maxWidth - inset * 2) / tabs.length;

        return ListenableBuilder(
          listenable: widget.pages ?? _position,
          builder: (context, _) {
            final tokens = AppThemeTokens.of(context);
            final position = _value;
            return Container(
              padding: const EdgeInsets.all(inset),
              decoration: BoxDecoration(
                color: tokens.brandTint,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    Positioned(
                      left: position * segmentWidth,
                      top: 0,
                      bottom: 0,
                      width: segmentWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.lg - inset,
                          ),
                          boxShadow: tokens.cardShadow,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < tabs.length; index++)
                          SizedBox(
                            width: segmentWidth,
                            child: _SegmentButton(
                              key: Key(
                                '${widget.keyPrefix}-tab-${tabs[index].name}',
                              ),
                              tab: tabs[index],
                              selected: _isSelected(position, index),
                              onTap: () => widget.onSelect(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// One tappable segment. It dips slightly under the finger so a tap is answered
/// before the content has finished sliding.
class _SegmentButton extends StatefulWidget {
  const _SegmentButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppSegmentedTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = widget.selected ? tokens.brand : tokens.mutedStrong;
    return GestureDetector(
      onTap: widget.onTap,
      // Opaque so the whole segment is tappable, not just the glyph the text
      // happens to cover.
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Center(
          // Shrinks the row rather than overflowing when the phone is narrow,
          // the label is long or the resident runs a large text size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: AppSegmentedTabs.slideDuration,
                  curve: AppSegmentedTabs.slideCurve,
                  builder: (context, animated, _) =>
                      Icon(widget.tab.icon, size: 18, color: animated),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: AppSegmentedTabs.slideDuration,
                  curve: AppSegmentedTabs.slideCurve,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  child: Text(widget.tab.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
