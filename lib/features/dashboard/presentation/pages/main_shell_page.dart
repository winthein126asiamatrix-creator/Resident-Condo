import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../facilities/presentation/pages/facilities_page.dart';
import '../../../maintenance/presentation/pages/maintenance_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/offline_banner.dart';
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
  Worker? _tabWorker;

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
    _pages = PageController(initialPage: controller.selectedTab.value);

    // Every tab change — a bar tap, a dashboard quick action, anything that
    // calls selectTab — animates the pager to match. The page equality check
    // is what keeps a swipe from bouncing: when the pager is already where the
    // tab says, there is nothing to animate to.
    _tabWorker = ever<int>(controller.selectedTab, (index) {
      if (!_pages.hasClients) {
        return;
      }
      final current = _pages.page?.round() ?? index;
      if (current == index) {
        return;
      }
      _animateToTab(index);
    });
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
    _suppressSwipeSync = false;
    _isNavigating = false;
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        // Read once, so the whole shell rebuilds on a change. This is the same
        // ConnectivityService observable the banner already uses; no second
        // controller, Rx variable or listener is introduced.
        final isOnline = Get.find<ConnectivityService>().isOnline.value;
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
                        }
                      },
                      children: [
                        DashboardPage(onSelectTab: controller.selectTab),
                        PaymentsPage(),
                        MaintenancePage(),
                        FacilitiesPage(),
                        ProfilePage(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNavBar(
            currentIndex: controller.selectedTab.value,
            onTap: (index) {
              if (_isNavigating) return;
              _jumpToTab(index);
            },
            items: <AppBottomNavItem>[
              AppBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'home'.tr,
              ),
              AppBottomNavItem(
                icon: Icons.payments_outlined,
                selectedIcon: Icons.payments_rounded,
                label: 'payments'.tr,
              ),
              AppBottomNavItem(
                icon: Icons.handyman_outlined,
                selectedIcon: Icons.handyman_rounded,
                label: 'maintenance'.tr,
              ),
              AppBottomNavItem(
                icon: Icons.event_available_outlined,
                selectedIcon: Icons.event_rounded,
                label: 'facilities'.tr,
              ),
              AppBottomNavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'profile'.tr,
              ),
            ],
          ),
        );
      },
    );
  }
}
