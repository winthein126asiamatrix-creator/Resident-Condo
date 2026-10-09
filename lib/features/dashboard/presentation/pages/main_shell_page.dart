import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../facilities/presentation/pages/facilities_page.dart';
import '../../../maintenance/presentation/pages/maintenance_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'dashboard_page.dart';
import '../controllers/dashboard_controller.dart';

/// The five tab root.
///
/// The pages live in a [PageView] so a horizontal swipe moves between them,
/// with the bottom navigation bar following along. Taps on the bar animate the
/// pager the other way, and [DashboardController.selectedTab] stays the single
/// source of truth for both directions.
///
/// Swiping is the only thing that changed: the bar, the pages, and the routes
/// beyond them are untouched.
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
    _suppressSwipeSync = true;
    _pages
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _suppressSwipeSync = false);
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
      () => Scaffold(
        body: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            // A finger starting a drag re-arms the swipe sync immediately, so a
            // swipe that interrupts a tap animation still lands the bar on the
            // page the resident settles on.
            if (notification.dragDetails != null) {
              _suppressSwipeSync = false;
            }
            return false;
          },
          child: PageView(
            controller: _pages,
            // First and last pages clamp on their own: Home cannot go further
            // right and Profile cannot go further left.
            onPageChanged: (index) {
              if (!_suppressSwipeSync) {
                controller.selectTab(index);
              }
            },
            children: [
              DashboardPage(onSelectTab: controller.selectTab),
              const PaymentsPage(),
              const MaintenancePage(),
              const FacilitiesPage(),
              const ProfilePage(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.selectedTab.value,
          onDestinationSelected: controller.selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: Icon(Icons.handyman_outlined),
              selectedIcon: Icon(Icons.handyman_rounded),
              label: 'Maintenance',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_rounded),
              label: 'Facilities',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}