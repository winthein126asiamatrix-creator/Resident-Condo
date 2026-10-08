import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_primary_action.dart';

/// Bottom sheet holding the free colour picker.
///
/// Deliberately dependency free: an HSV square plus a hue strip is enough to
/// reach any colour, and it keeps the template's package list untouched.
///
/// The sheet reports every drag straight back through [onChanged], so the
/// resident sees the home screen preview behind it change as they move their
/// thumb. [onConfirm] is what actually commits.
Future<Color?> showAppColorPickerSheet(
  BuildContext context, {
  required Color initial,
  required ValueChanged<Color> onChanged,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (sheetContext) => _AppColorPickerSheet(
      initial: initial,
      onChanged: onChanged,
    ),
  );
}

class _AppColorPickerSheet extends StatefulWidget {
  const _AppColorPickerSheet({required this.initial, required this.onChanged});

  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<_AppColorPickerSheet> createState() => _AppColorPickerSheetState();
}

class _AppColorPickerSheetState extends State<_AppColorPickerSheet> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;

  /// Guards against the hex field echoing back a value it is mid-way through
  /// typing, which would fight the resident's keystrokes.
  bool _isEditingHex = false;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexController = TextEditingController(text: _hexOf(widget.initial));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  static String _hexOf(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  void _update(HSVColor next) {
    setState(() {
      _hsv = next;
      if (!_isEditingHex) {
        _hexController.text = _hexOf(_color);
        _hexController.selection = TextSelection.collapsed(
          offset: _hexController.text.length,
        );
      }
    });
    widget.onChanged(_color);
  }

  void _onHexChanged(String value) {
    final parsed = _parseHex(value);
    if (parsed == null) {
      return;
    }
    setState(() {
      _hsv = HSVColor.fromColor(parsed);
    });
    widget.onChanged(parsed);
  }

  /// Accepts `#RRGGBB` with or without the hash, in either case.
  static Color? _parseHex(String raw) {
    final cleaned = raw.replaceAll('#', '').trim();
    if (cleaned.length != 6) {
      return null;
    }
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      // Lifts the sheet above the keyboard while the hex field is focused.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              12,
              AppSpacing.gutter,
              AppSpacing.gutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetGrabber(),
                const SizedBox(height: AppSpacing.fieldGap),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Custom color',
                            style: TextStyle(
                              color: tokens.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Any color you like. The app builds the rest of '
                            'the palette around it.',
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.fieldLabelGap),
                    _SelectedSwatch(color: _color, tokens: tokens),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _SaturationValueField(
                  hue: _hsv.hue,
                  saturation: _hsv.saturation,
                  value: _hsv.value,
                  onChanged: (saturation, value) => _update(
                    _hsv.withSaturation(saturation).withValue(value),
                  ),
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                _HueStrip(
                  hue: _hsv.hue,
                  onChanged: (hue) => _update(_hsv.withHue(hue)),
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                _RecentSwatches(
                  colors: _recentColors,
                  onSelected: (color) => _update(HSVColor.fromColor(color)),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _HexField(
                  controller: _hexController,
                  tokens: tokens,
                  onChanged: _onHexChanged,
                  onEditingChanged: (editing) => _isEditingHex = editing,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                AppPrimaryAction(
                  key: const Key('appearance-color-picker-confirm'),
                  onPressed: () => Navigator.of(context).pop(_color),
                  label: 'Use this color',
                  icon: Icons.check_rounded,
                  backgroundColor: _color,
                ),
                const SizedBox(height: AppSpacing.fieldLabelGap),
                Center(
                  child: TextButton(
                    key: const Key('appearance-color-picker-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Colours offered for one tap, so a resident who wants "something like that"
  /// is not forced to drag.
  static const _recentColors = <Color>[
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF059669),
  ];
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: AppPalette.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The filled circle beside the title, echoing the selected swatch in the grid.
class _SelectedSwatch extends StatelessWidget {
  const _SelectedSwatch({required this.color, required this.tokens});

  final Color color;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.border,
          width: color.computeLuminance() > 0.6 ? 1 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

/// The two dimensional saturation and value field.
///
/// Painted as two overlaid gradients: white to the pure hue across, then clear
/// to black down. That is the standard construction and it stays accurate for
/// every hue without a shader.
class _SaturationValueField extends StatelessWidget {
  const _SaturationValueField({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  static const _height = 168.0;

  @override
  Widget build(BuildContext context) {
    final pureHue = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final tokens = AppThemeTokens.of(context);

    void handle(Offset local, Size size) {
      // Clamped so a drag that leaves the field keeps the last value instead of
      // wrapping around to the far side.
      final nextSaturation = (local.dx / size.width).clamp(0.0, 1.0);
      final nextValue = 1 - (local.dy / size.height).clamp(0.0, 1.0);
      onChanged(nextSaturation, nextValue);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, _height);
        void update(Offset local) => handle(local, size);

        return GestureDetector(
          key: const Key('appearance-picker-saturation-value'),
          onPanDown: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    gradient: LinearGradient(
                      colors: [Colors.white, pureHue],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xFF000000)],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: tokens.border),
                  ),
                ),
                Positioned(
                  left: saturation * size.width - 13,
                  top: (1 - value) * size.height - 13,
                  child: const _FieldThumb(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FieldThumb extends StatelessWidget {
  const _FieldThumb();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The horizontal hue strip.
class _HueStrip extends StatelessWidget {
  const _HueStrip({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));

        return GestureDetector(
          key: const Key('appearance-picker-hue-strip'),
          onPanDown: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: SizedBox(
            height: _height,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: tokens.border),
                  ),
                ),
                Positioned(
                  left: (hue * width - 14).clamp(0.0, width - 28),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.26),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentSwatches extends StatelessWidget {
  const _RecentSwatches({required this.colors, required this.onSelected});

  final List<Color> colors;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              label: 'Use ${color.toARGB32().toRadixString(16).substring(2)}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onSelected(color),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.border),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hex entry, for a resident who already knows the value they want.
class _HexField extends StatelessWidget {
  const _HexField({
    required this.controller,
    required this.tokens,
    required this.onChanged,
    required this.onEditingChanged,
  });

  final TextEditingController controller;
  final AppThemeTokens tokens;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onEditingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hex value',
          style: TextStyle(
            color: tokens.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        TextField(
          key: const Key('appearance-color-hex-field'),
          controller: controller,
          onChanged: onChanged,
          onTap: () => onEditingChanged(true),
          onEditingComplete: () => onEditingChanged(false),
          onTapOutside: (_) {
            onEditingChanged(false);
            FocusScope.of(context).unfocus();
          },
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
            LengthLimitingTextInputFormatter(7),
          ],
          style: TextStyle(
            color: tokens.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
          decoration: InputDecoration(
            hintText: '#0F766E',
            prefixIcon: Icon(Icons.tag_rounded, size: 20, color: tokens.muted),
            filled: true,
            fillColor: tokens.surfaceMuted,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: tokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: tokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: tokens.brand, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}