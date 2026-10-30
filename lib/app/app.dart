import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/config/app_environment.dart';
import 'deep_link_state.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_locale_controller.dart';
import '../core/localization/app_translations.dart';
import '../core/network/api_binding.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/refresh_registry.dart';
import '../core/services/firebase_service.dart';
import '../core/utils/super_print.dart';
import '../features/appearance/presentation/bindings/appearance_binding.dart';
import '../features/appearance/presentation/controllers/appearance_controller.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../features/notifications/domain/entities/notification_item.dart';
import '../features/session/presentation/controllers/session_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'package:app_links/app_links.dart';

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

  /// Watches for a notification the resident tapped.
  Worker? _notificationTapWorker;

  /// Firebase, registered by `FirebaseBinding` in `main` before this widget
  /// exists, so it is looked up rather than created here.
  FirebaseService? _firebase;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _deepLinkSubscription;

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

    if (Get.isRegistered<FirebaseService>()) {
      _firebase = Get.find<FirebaseService>();
      // A tap that launched the app is captured before this widget exists, so the
      // first call is made directly as well; the worker covers every later tap.
      _notificationTapWorker = ever<RemoteMessage?>(
        _firebase!.pendingNotificationTap,
        (_) => unawaited(_openNotificationsFromTap()),
      );
      unawaited(_openNotificationsFromTap());
    }
    unawaited(_startDeepLinkListener());
  }

  Future<void> _startDeepLinkListener() async {
  _appLinks = AppLinks();

  try {
    final initialUri = await _appLinks.getInitialLink();

    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
  } catch (error) {
    superPrint(
      'Initial deep link error: $error',
      title: 'Deep Link',
    );
  }

  _deepLinkSubscription = _appLinks.uriLinkStream.listen(
    _handleDeepLink,
    onError: (Object error) {
      superPrint(
        'Deep link stream error: $error',
        title: 'Deep Link',
      );
    },
  );
}

void _handleDeepLink(Uri uri) {
  final expectedHost = AppEnvironment.current.isProduction
      ? 'matrix-condo.web.app'
      : 'matrix-condo-dev.web.app';

  if (uri.scheme != 'https' || uri.host != expectedHost) {
    return;
  }

  final segments = uri.pathSegments;
  if (segments.length == 3 &&
      segments[0] == 'payments' &&
      segments[1] == 'detail') {
    final invoiceId = segments[2];
    if (invoiceId.isNotEmpty) {
      superPrint('Opening invoice detail: $invoiceId', title: 'Deep Link');
      setPendingInvoiceId(invoiceId);
      openPendingInvoiceIfReady();
      return;
    }
  }
}

  /// Opens the notifications page for a notification the resident tapped.
  ///
  /// Two things have to be true before the page can open, and neither is the
  /// service's business: there must be a route to change, and a resident to show
  /// it to. A tap that launched a terminated app is therefore held while the
  /// splash is still deciding whether anyone is signed in — the route change the
  /// splash makes a moment later would otherwise undo the navigation — and a tap
  /// with no signed-in resident is dropped rather than sent to a login screen.
  Future<void> _openNotificationsFromTap() async {
    final firebase = _firebase;
    if (firebase == null) return;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (firebase.pendingNotificationTap.value != null &&
        Get.currentRoute == AppRoutes.splash &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final message = firebase.pendingNotificationTap.value;
    if (message == null) return;
    firebase.consumePendingNotificationTap();
    if (!Get.isRegistered<SessionController>() ||
        Get.find<SessionController>().session.value == null) {
      superPrint(
        'Notification tap dropped: no signed-in resident.',
        title: 'Firebase Message',
      );
      return;
    }
    if (Get.currentRoute == AppRoutes.notifications) {
      return;
    }
    superPrint({
      'messageId': message.messageId,
      'type': message.data[FirebaseService.typeDataKey],
    }, title: 'Firebase notification opened');
    await Get.offNamed<void>(
      _destinationFor(message.data[FirebaseService.typeDataKey]),
    );
  }

  /// Where a tapped notification should open.
  ///
  /// The type travels in the FCM `data` payload, so the destination is decided by
  /// the same [NotificationType] vocabulary the list uses, and only through
  /// routes the app already has.
  ///
  /// Anything unrecognised, or missing, falls back to the notifications list:
  /// that page exists to explain an update the app cannot place, so it is the one
  /// destination that is always correct. A type with no route of its own lands
  /// there too rather than guessing.
  String _destinationFor(String? rawType) {
    final type = NotificationTypeWire.fromWire(rawType);
    final route = switch (type) {
      NotificationType.newAnnouncement => AppRoutes.announcements,
      NotificationType.paymentDue ||
      NotificationType.paymentSuccessful => AppRoutes.paymentHistory,
      NotificationType.facilityBookingConfirmed => AppRoutes.myReservations,
      NotificationType.visitorArrival => AppRoutes.visitors,
      NotificationType.leaseRenewal => AppRoutes.lease,
      NotificationType.violationIssued => AppRoutes.rules,
      NotificationType.complaintUpdated => AppRoutes.complaints,
      // Detail pages need an id this payload may not carry, so these two stay on
      // the list rather than opening something guessed.
      NotificationType.maintenanceUpdated ||
      NotificationType.unknown ||
      null => AppRoutes.notifications,
    };
    return route;
  }

  @override
  void dispose() {
    _connectivityWorker?.dispose();
    _notificationTapWorker?.dispose();
      unawaited(_deepLinkSubscription?.cancel());
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
    return Obx(() {
      final brightness = _appearance.themeMode == ThemeMode.dark
          ? Brightness.dark
          : _appearance.themeMode == ThemeMode.light
          ? Brightness.light
          : AppearanceController.currentPlatformBrightness();
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness,
        ),
        child: GetMaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: _appearance.theme,
          darkTheme: _appearance.darkTheme,
          themeMode: _appearance.themeMode,
          translations: AppTranslations(),
          unknownRoute: GetPage<dynamic>(
    name: '/unknown',
    page: () {
      debugPrint(
        'UNKNOWN ROUTE: ${Get.currentRoute}, '
        'arguments=${Get.arguments}',
      );
      return const Scaffold(
        body: Center(
          child: Text('Unknown route'),
        ),
      );
    },
  ),
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
    });
  }
}
