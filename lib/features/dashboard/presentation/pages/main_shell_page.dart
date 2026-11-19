import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/branded_loading_view.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../config/domain/entities/condo_config.dart';
import '../../../config/presentation/controllers/condo_config_controller.dart';
import '../../../facilities/presentation/pages/facilities_page.dart';
import '../../../maintenance/presentation/pages/maintenance_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import 'dashboard_page.dart';
import '../controllers/dashboard_controller.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  late final DashboardController controller = Get.find<DashboardController>();
  late final PageController _pages;
  late List<_ShellTab> _tabs;
  Worker? _tabWorker;
  Worker? _featureWorker;

  /// Set while a tap-driven page animation is running.
  ///
  /// A programmatic slide passes every page on the way to its target, and each
  /// one fires [PageView.onPageChanged]. Without the guard the navigation bar
  /// would visibly cycle through the pages in between.
  bool _suppressSwipeSync = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    _pages = PageController(
      initialPage: controller.selectedTab.value.clamp(0, _tabs.length - 1),
    );

    // Every tab change — a bar tap, a dashboard quick action, anything that
    // calls selectTab — animates the pager to match. The page equality check
    // is what keeps a swipe from bouncing: when the pager is already where the
    // tab says, there is nothing to animate to.
    _tabWorker = ever<int>(controller.selectedTab, (index) {
      if (!_pages.hasClients || index >= _tabs.length) {
        return;
      }
      final current = _pages.page?.round() ?? index;
      if (current == index) {
        return;
      }
      _animateToTab(index);
    });
    _featureWorker = ever<String>(controller.selectedFeature, (feature) {
      final index = _tabs.indexWhere((tab) => tab.feature == feature);
      if (index >= 0) {
        controller.selectTab(index);
      }
    });
  }

  _ShellTab _tab({
    required String feature,
    required Widget page,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return _ShellTab(
      feature: feature,
      page: page,
      item: AppBottomNavItem(
        icon: icon,
        selectedIcon: selectedIcon,
        label: label,
      ),
    );
  }

  List<_ShellTab> _buildTabs() {
    final config = Get.isRegistered<CondoConfigController>()
        ? Get.find<CondoConfigController>()
        : null;
    bool enabled(CondoFeature feature) =>
        config == null || config.isFeatureEnabled(feature);
    return <_ShellTab>[
      _tab(
        feature: 'dashboard',
        page: DashboardPage(onSelectFeature: controller.selectFeature),
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'home'.tr,
      ),
      if (enabled(CondoFeature.payments))
        _tab(
          feature: 'payments',
          page: const PaymentsPage(),
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments_rounded,
          label: 'payments'.tr,
        ),
      if (enabled(CondoFeature.maintenance))
        _tab(
          feature: 'maintenance',
          page: const MaintenancePage(),
          icon: Icons.handyman_outlined,
          selectedIcon: Icons.handyman_rounded,
          label: 'maintenance'.tr,
        ),
      if (enabled(CondoFeature.facilities))
        _tab(
          feature: 'facilities',
          page: const FacilitiesPage(),
          icon: Icons.event_available_outlined,
          selectedIcon: Icons.event_rounded,
          label: 'facilities'.tr,
        ),
      _tab(
        feature: 'profile',
        page: const ProfilePage(),
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'profile'.tr,
      ),
    ];
  }

  void _animateToTab(int index) {
    if (_isNavigating) return;
    _isNavigating = true;
    _suppressSwipeSync = true;
    _pages
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _suppressSwipeSync = false;
          _isNavigating = false;
        });
  }

  void _jumpToTab(int index) {
    if (_isNavigating) return;
    _isNavigating = true;
    _suppressSwipeSync = true;
    if (_pages.hasClients) {
      _pages.jumpToPage(index);
    }
    controller.selectTab(index);
    if (index < _tabs.length) {
      controller.selectFeature(_tabs[index].feature);
    }
    _suppressSwipeSync = false;
    _isNavigating = false;
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _featureWorker?.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    return Obx(() {
      final session = Get.isRegistered<SessionController>()
          ? Get.find<SessionController>().session.value
          : null;
      // if (session == null) {
      //   // Login has saved the tokens, but the complete AuthUser from `/auth/me`
      //   // has not arrived yet. Keep every protected screen off stage.
      //   return _buildSessionInitialization(auth);
      // }
      // Read once, so the whole shell rebuilds on a change. This is the same
      // ConnectivityService observable the banner already uses; no second
      // controller, Rx variable or listener is introduced.
      final isOnline = Get.find<ConnectivityService>().isOnline.value;
      final tabs = _buildTabs();
      _tabs = tabs;
      final selectedIndex = controller.selectedTab.value.clamp(
        0,
        tabs.length - 1,
      );
      return Scaffold(
        body: Column(
          children: [
            OfflineBannerSlot(applyStatusBarInset: true),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !isOnline,
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) {
                      _suppressSwipeSync = false;
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (index) {
                      if (!_suppressSwipeSync) {
                        controller.selectTab(index);
                        if (index < tabs.length) {
                          controller.selectFeature(tabs[index].feature);
                        }
                      }
                    },
                    children: [for (final tab in tabs) tab.page],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            if (_isNavigating) return;
            _jumpToTab(index);
          },
          items: [for (final tab in tabs) tab.item],
        ),
      );
    });
  }

  Widget _buildSessionInitialization(AuthController? auth) {
    final error = auth?.sessionInitializationError.value;
    if (error == null) {
      return const Scaffold(
        body: BrandedLoadingView(message: 'Preparing your residence'),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: AppStateMessage(
          title: 'Unable to load your profile',
          message: error,
          icon: Icons.person_off_outlined,
          actionLabel: 'Try again',
          onAction: auth == null
              ? null
              : () => unawaited(auth.fetchCurrentUser(force: true)),
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.feature,
    required this.page,
    required this.item,
  });

  final String feature;
  final Widget page;
  final AppBottomNavItem item;
}
