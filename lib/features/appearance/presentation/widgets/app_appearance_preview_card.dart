import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme_tokens.dart';

/// A realistic miniature of the resident home screen, painted with the colour
/// the resident is currently trying.
///
/// This is the point of the screen: a palette tells you nothing about how an app
/// will actually look. This card is a scaled down home screen built from the
/// same [AppThemeTokens] the app will use, so the greeting, balance card, the
/// "Pay Now" button, the shortcut tiles, the announcement, the selected bottom
/// navigation item and the progress bar all change together.
///
/// It is inert by design: the tiles do not respond to taps, because a preview
/// that navigated would take the resident off the screen they are configuring.
class AppAppearancePreviewCard extends StatelessWidget {
  const AppAppearancePreviewCard({
    required this.tokens,
    required this.greeting,
    required this.unitLabel,
    required this.balanceAmount,
    required this.balanceDue,
    super.key,
  });

  /// The tokens derived from the colour and brightness being previewed.
  final AppThemeTokens tokens;

  final String greeting;
  final String unitLabel;
  final String balanceAmount;
  final String balanceDue;

  /// The preview is a device screen at roughly 0.62 of the phone's width, so
  /// every dimension inside is scaled from the real layout by hand rather than
  /// measured, which keeps it legible and free of layout maths.
  static const _contentPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xxl);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.canvas,
        borderRadius: radius,
        border: Border.all(color: tokens.border),
        boxShadow: tokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A slim status bar so the card reads as a device rather than a card
            // of content. Uses the platform's own brightness, since the preview
            // is about the app, not the phone chrome.
            _PreviewStatusBar(tokens: tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _contentPadding,
                _contentPadding,
                _contentPadding,
                _contentPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PreviewGreeting(
                    tokens: tokens,
                    greeting: greeting,
                    unitLabel: unitLabel,
                  ),
                  const SizedBox(height: 10),
                  _PreviewBalanceCard(
                    tokens: tokens,
                    amount: balanceAmount,
                    due: balanceDue,
                  ),
                  const SizedBox(height: 8),
                  _PreviewShortcuts(tokens: tokens),
                  const SizedBox(height: 8),
                  _PreviewAnnouncement(tokens: tokens),
                ],
              ),
            ),
            _PreviewNavigationBar(tokens: tokens),
          ],
        ),
      ),
    );
  }
}

class _PreviewStatusBar extends StatelessWidget {
  const _PreviewStatusBar({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      color: tokens.canvas,
      child: Row(
        children: [
          Text(
            '9:41',
            style: TextStyle(
              color: tokens.ink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 10, color: tokens.ink),
          const SizedBox(width: 4),
          Icon(Icons.wifi_rounded, size: 10, color: tokens.ink),
          const SizedBox(width: 4),
          Icon(Icons.battery_full_rounded, size: 10, color: tokens.ink),
        ],
      ),
    );
  }
}

class _PreviewGreeting extends StatelessWidget {
  const _PreviewGreeting({
    required this.tokens,
    required this.greeting,
    required this.unitLabel,
  });

  final AppThemeTokens tokens;
  final String greeting;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unitLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _PreviewAvatar(tokens: tokens),
      ],
    );
  }
}

class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: tokens.brandSoft, shape: BoxShape.circle),
      child: Center(
        child: Text(
          'M',
          style: TextStyle(
            color: tokens.brand,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// The balance card: the single place where the brand colour is used as a fill,
/// because it is the one element the resident acts on most often.
class _PreviewBalanceCard extends StatelessWidget {
  const _PreviewBalanceCard({
    required this.tokens,
    required this.amount,
    required this.due,
  });

  final AppThemeTokens tokens;
  final String amount;
  final String due;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Outstanding balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onBrand.withValues(alpha: 0.82),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.receipt_long_rounded,
                size: 12,
                color: tokens.onBrand.withValues(alpha: 0.82),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: tokens.onBrand,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  due,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onBrand.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // A progress track, so the brand colour is shown as an indicator fill
          // too and not only as a large solid surface.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: tokens.onBrand.withValues(alpha: 0.24),
                ),
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(height: 5, color: tokens.onBrand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // The primary action. Its fill and label both come from the tokens, so
          // this is the clearest read on whether the chosen colour works.
          Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.onBrand,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Pay Now',
              style: TextStyle(
                color: tokens.brand,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maintenance and Facilities, the two shortcuts residents reach for most.
class _PreviewShortcuts extends StatelessWidget {
  const _PreviewShortcuts({required this.tokens});

  final AppThemeTokens tokens;

  static const _items = <({IconData icon, String label, String value})>[
    (
      icon: Icons.handyman_rounded,
      label: 'Maintenance',
      value: '1 open',
    ),
    (icon: Icons.event_available_rounded, label: 'Facilities', value: '3 free'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in _items) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: tokens.brandTint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    // Active icon: tinted by the brand, the same treatment the
                    // real shortcut rows use.
                    child: Icon(item.icon, size: 14, color: tokens.brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.ink,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PreviewAnnouncement extends StatelessWidget {
  const _PreviewAnnouncement({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tokens.brandTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.campaign_rounded,
              size: 14,
              color: tokens.brand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pool maintenance on Friday',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '9:00 AM – 12:00 PM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.muted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // An important link, in the brand colour.
          Text(
            'Read',
            style: TextStyle(
              color: tokens.brand,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom navigation, showing the selected item in the brand colour with the
/// Material indicator pill behind it.
class _PreviewNavigationBar extends StatelessWidget {
  const _PreviewNavigationBar({required this.tokens});

  final AppThemeTokens tokens;

  static const _destinations = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.payments_outlined,
      selected: Icons.payments_rounded,
      label: 'Payments'
    ),
    (
      icon: Icons.handyman_outlined,
      selected: Icons.handyman_rounded,
      label: 'Repairs'
    ),
    (
      icon: Icons.person_outline_rounded,
      selected: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _destinations.length; index++)
            Expanded(
              child: _PreviewNavItem(
                destination: _destinations[index],
                selected: index == 0,
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  const _PreviewNavItem({
    required this.destination,
    required this.selected,
    required this.tokens,
  });

  final ({IconData icon, IconData selected, String label}) destination;
  final bool selected;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? tokens.brand : tokens.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            // The Material 3 navigation indicator: a soft brand pill behind the
            // active icon only.
            color: selected ? tokens.brandSoft : const Color(0x00000000),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Icon(
            selected ? destination.selected : destination.icon,
            size: 16,
            color: foreground,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 8.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

