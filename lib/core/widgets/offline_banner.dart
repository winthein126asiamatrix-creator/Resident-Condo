import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_palette.dart';
import '../network/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  /// Height the banner occupies once rendered.
  ///
  /// Informational. The app bar that hosts it declares this so its
  /// [PreferredSizeWidget.preferredSize] stays honest, but a [Scaffold] measures
  /// the app bar's real height when it lays out, so the banner being a little
  /// taller under a large text scale changes nothing.
  static const double height = 29;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppPalette.ink,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 15, color: Colors.red),
          SizedBox(width: 8),
          Text(
            'No internet connection',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
class OfflineBannerSlot extends StatelessWidget {
  const OfflineBannerSlot({super.key, this.applyStatusBarInset = false});

  
  final bool applyStatusBarInset;

  @override
  Widget build(BuildContext context) {
    // Absent in tests that pump a screen without the full app graph.
    if (!Get.isRegistered<ConnectivityService>()) {
      return const SizedBox.shrink();
    }
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        child: Get.find<ConnectivityService>().isOnline.value
            ? const SizedBox.shrink(key: Key('offline-banner-hidden'))
            : _OfflineBannerHost(applyStatusBarInset: applyStatusBarInset),
      ),
    );
  }
}

class _OfflineBannerHost extends StatelessWidget {
  const _OfflineBannerHost({required this.applyStatusBarInset});

  final bool applyStatusBarInset;

  @override
  Widget build(BuildContext context) {
    if (!applyStatusBarInset) {
      return const OfflineBanner();
    }
     return Padding(
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top,
    ),
    child: const OfflineBanner(),
  );
  }
}
