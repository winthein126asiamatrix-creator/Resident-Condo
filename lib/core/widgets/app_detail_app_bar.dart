import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';

/// The custom app bar shared by the detail and form screens.
///
/// It deliberately replaces the default Material [AppBar]: it is safe area
/// aware, keeps the same top spacing as the SafeArea based screens, carries an
/// optional helper line under the title and separates itself from the content
/// with a hairline. Living in `core/widgets` means the screens cannot drift
/// apart.
class AppDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppDetailAppBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    super.key,
  });

  final String title;

  /// Short helper line under the title. Optional: screens that never used one
  /// keep the same single line bar.
  final String? subtitle;

  /// Defaults to popping the current route, so a screen can pass its own
  /// navigation call when it needs to do more than that.
  final VoidCallback? onBack;

  /// Replaces the back button, for a screen that opens with something else
  /// (a menu, a logo). Ignored when [showBackButton] is false.
  final Widget? leading;

  /// Trailing actions, such as a refresh or overflow button. They are laid out
  /// from the trailing edge, each with a comfortable touch target.
  final List<Widget> actions;

  /// Set to false for a screen that is the root of a tab and has nothing to go
  /// back to.
  final bool showBackButton;

  /// Height of the bar itself, excluding the status bar and the top spacing.
  static const _barHeight = 70.0;

  /// Height of the row inside the bar. Fixed so trailing actions cannot make
  /// one screen's bar taller than another's.
  static const _contentHeight = 42.0;

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + _topInset + AppSpacing.pageTop);

  /// The status bar inset, read from the implicit view because a
  /// [PreferredSizeWidget] has no [BuildContext] of its own.
  double get _topInset =>
      WidgetsBinding.instance.platformDispatcher.implicitView?.padding.top ?? 0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.canvas,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        padding: EdgeInsets.fromLTRB(16, topInset + AppSpacing.pageTop, 20, 14),
        // Fixed height so a screen with trailing actions ends up with exactly
        // the same bar as a screen without them.
        child: SizedBox(
          height: _contentHeight,
          child: Row(
            children: [
              if (showBackButton)
                leading ?? _AppBarBackButton(onBack: onBack)
              else
                ?leading,
              const SizedBox(width: 12),
              // Single lines with ellipsis so a narrow phone or a large text
              // scale can never push the toolbar out of its bounds.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 18,
                        height: 1.2,
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final action in actions)
                Padding(padding: const EdgeInsets.only(left: 4), child: action),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarBackButton extends StatelessWidget {
  const _AppBarBackButton({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: 'Back',
        child: InkWell(
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}
