import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import '../theme/app_radius.dart';


import '../theme/app_spacing.dart';


import '../theme/app_theme_tokens.dart';

/// Secondary call to action: an outlined button with the same height, radius
/// and typography as [AppPrimaryAction].
///
/// Used wherever a screen needs a second, less important action next to its
/// primary one, or for an action that should read as reversible.
class AppOutlinedButton extends StatelessWidget {
  AppOutlinedButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Full width by default, matching [AppPrimaryAction].
  final bool expand;

  /// Defaults to the theme's brand colour.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final enabled = onPressed != null && !isLoading;
    final color = enabled ? (foregroundColor ?? tokens.brand) : tokens.faint;

    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: tokens.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: AppSpacing.buttonHeight,
          width: expand ? double.infinity : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 24),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, size: 20, color: color),
                  10.w.widthBox(),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15.5.sp,
                      letterSpacing: 0.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Low emphasis text action, used for "Back to Facilities" style links and
/// third actions in a dialog.
class AppTextButton extends StatelessWidget {
  AppTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Defaults to the theme's brand colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null ? SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: onPressed == null
            ? tokens.faint
            : (color ?? tokens.brand),
        minimumSize: Size(0, AppSpacing.minTouchTarget),
        textStyle: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w700),
      ),
    );
  }
}
