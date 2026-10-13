import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/app_locale_controller.dart';
import '../core/localization/app_translations.dart';
import '../core/network/api_binding.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/refresh_registry.dart';
import '../features/appearance/presentation/bindings/appearance_binding.dart';
import '../features/appearance/presentation/controllers/appearance_controller.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

/// The application root.
///
/// The theme is built from [AppearanceController], which is the single source of
/// truth for the resident's brand colour. Registering it here, before the first
/// build, means the saved colour is applied on the very first frame rather than
/// flashing the default and correcting a moment later.
///
/// The [Obx] is the whole integration: the theme is built from the controller's
/// *applied* preference, so only "Apply Theme" — never a preview — rebuilds
/// `GetMaterialApp` and repaints every mounted screen at once.
class CondoResidentApp extends StatefulWidget {
  const CondoResidentApp({this.initialLocale = const Locale('en'), super.key});

  final Locale initialLocale;

  @override
  State<CondoResidentApp> createState() => _CondoResidentAppState();
}

class _CondoResidentAppState extends State<CondoResidentApp> {
  late final AppearanceController _appearance;
  late final ConnectivityService _connectivity;
  late final AppLocaleController _localeController;

  /// Watches [ConnectivityService.isOnline] for the transition back to online.
  Worker? _connectivityWorker;

  @override
  void initState() {
    super.initState();
    // App scoped, so they are registered before the first frame. The binding is
    // idempotent and the routes that need them run it again harmlessly.
    ApiBinding.register();
    AppearanceBinding().dependencies();
    _appearance = Get.find<AppearanceController>();

    Get.put<AppLocaleController>(
      AppLocaleController(initialLocale: widget.initialLocale),
      permanent: true,
    );
    _localeController = Get.find<AppLocaleController>();

    // Connectivity is app scoped like the client it reports on: the banner is
    // shared by every screen, and the worker below has to outlive any route.
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<RefreshRegistry>(RefreshRegistry(), permanent: true);
    _connectivity = Get.find<ConnectivityService>();

    _connectivityWorker = ever(_connectivity.isOnline, (_) {
      if (!_connectivity.isOnline.value) return;
      // The backend is reachable again. Two things follow, and only ever on the
      // way back online: the active screen takes up any data that went stale,
      // and a session that was only admitted locally is put to the server.
      _refreshActiveScreen();
      _revalidateSession();
    });
  }

  @override
  void dispose() {
    _connectivityWorker?.dispose();
    super.dispose();
  }

  /// Re-fetches the active screen's GET data after a reconnect.
  ///
  /// Scoped on purpose. Only the Home tab's dashboard is wired up, and the
  /// registry re-fetches it only if its data went stale: a screen whose last
  /// fetch succeeded is left exactly as it is. Every other tab and screen is
  /// untouched, so a reconnect never re-issues requests the resident never
  /// asked for — and never repeats a write.
  Future<void> _refreshActiveScreen() async {
    if (Get.currentRoute != AppRoutes.home) return;
    if (!Get.isRegistered<DashboardController>()) return;
    if (Get.find<DashboardController>().selectedTab.value != 0) return;
    await Get.find<RefreshRegistry>().refreshIfStale(
      DashboardController.screen,
    );
  }

  /// Asks the server about a session that was admitted on a network failure.
  ///
  /// Skipped for a session the server has already verified, so reconnecting
  /// costs nothing when the session was never in doubt.
  Future<void> _revalidateSession() async {
    if (!Get.isRegistered<AuthController>()) return;
    if (!Get.find<AuthController>().isUnverified.value) return;
    await Get.find<AuthController>().revalidateSession();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: _appearance.theme,
        darkTheme: _appearance.darkTheme,
        themeMode: _appearance.themeMode,
        translations: AppTranslations(),
        locale: _localeController.locale,
        fallbackLocale: const Locale('en'),
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('my'),
          Locale('zh'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );
  }
}
