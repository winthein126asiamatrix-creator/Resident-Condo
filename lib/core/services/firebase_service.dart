import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../firebase_options.dart';
import '../utils/super_print.dart';

/// Owns the Firebase SDK for the whole app: initialisation, the notification
/// permission, and the FCM device token.
///
/// Registered once, permanently, by `FirebaseBinding` before the first frame,
/// because every entry point into Messaging needs the SDK to be up already and a
/// second `Firebase.initializeApp` call would fail.
///
/// Three deliberate omissions, because they belong to a later slice: nothing
/// displays a foreground notification, nothing listens for a background message,
/// and the token is not sent anywhere. It is held in memory only, so no token
/// ends up in a log file or in the keychain before the backend is told about it.
///
/// Every failure path is swallowed. Firebase not starting is not a reason for a
/// resident to be unable to pay their rent, so the app carries on without push
/// and the reason is recorded through [superPrint], which prints in debug only.
class FirebaseService extends GetxService {
  /// True once `Firebase.initializeApp` has completed successfully.
  ///
  /// Everything else in this class checks it, so a failed initialisation
  /// degrades to "no notifications" instead of throwing on the first call.
  final isReady = false.obs;

  /// The FCM registration token, or null while it has not been issued yet.
  ///
  /// Held in memory only. Nothing registers it with the backend yet, so it is
  /// not persisted: a token that outlives the process would have to be handed
  /// back to the server anyway, and a stale one on disk is worse than none.
  final deviceToken = RxnString();

  /// The last notification permission the app asked for or observed.
  final permissionStatus = Rxn<AuthorizationStatus>();

  /// The in-flight (or completed) initialisation, so a second call joins the
  /// first instead of starting a competing `Firebase.initializeApp`.
  Future<void>? _initialising;

  /// Whether the system prompt has already been shown this run.
  ///
  /// The permission is only ever requested while iOS/Android report
  /// "not determined", but this is kept as well so a resident who was sent to
  /// sign-in cannot be prompted a second time by the session being adopted
  /// again on a reconnect.
  bool _permissionRequested = false;

  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Initialises Firebase with the options generated for this platform.
  ///
  /// Safe to call more than once: the second call awaits the first. `main`
  /// awaits this before the first frame, so nothing can reach Messaging before
  /// the SDK is ready.
  Future<void> initialize() {
    return _initialising ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isReady.value = true;
      superPrint('Firebase initialised', title: 'Firebase Service');
    } catch (error) {
      // Unsupported desktop targets and a missing platform config land here.
      isReady.value = false;
      superPrint('Firebase initialisation failed: $error', title: 'Firebase Service');
    }
  }

  @override
  void onClose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    super.onClose();
  }

  /// Asks for notification permission if the resident has never been asked, then
  /// fetches the FCM token.
  ///
  /// Called from the one point where the app knows a resident is signed in, so
  /// the prompt appears in front of someone who is actually using the app rather
  /// than over the splash, and never before a sign-in.
  ///
  /// A denied permission is a final answer, not an error: nothing is shown again
  /// and no token is fetched, but the app is untouched. Neither branch can throw
  /// back into the caller, so this is safe to fire and forget.
  Future<void> onResidentSignedIn() async {
    if (!isReady.value) {
      return;
    }
    final settings = await _resolvePermission();
    if (settings == null) {
      return;
    }
    permissionStatus.value = settings.authorizationStatus;
    if (!_canReceive(settings.authorizationStatus)) {
      superPrint(
        'Notification permission is ${settings.authorizationStatus.name}; '
        'no FCM token requested.',
        title: 'Firebase Service',
      );
      return;
    }
    await refreshDeviceToken();
  }

  /// The current permission, asking for it the first time only.
  ///
  /// `requestPermission` is a no-op below Android 13, and iOS returns the stored
  /// answer without prompting once the resident has decided, so asking here is
  /// what keeps the prompt to a single appearance. Provisional is left off: it
  /// would deliver notifications quietly, which is a product decision rather
  /// than a technical one.
  Future<NotificationSettings?> _resolvePermission() async {
    final messaging = FirebaseMessaging.instance;
    try {
      final current = await messaging.getNotificationSettings();
      if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
        return current;
      }
      if (_permissionRequested) {
        return current;
      }
      _permissionRequested = true;
      return await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (error) {
      superPrint(
        'Could not read the notification permission: $error',
        title: 'Firebase Service',
      );
      return null;
    }
  }

  /// Whether a notification permission in this state lets messages through.
  ///
  /// Provisional counts: iOS delivers quietly under it, so the token is worth
  /// having even though the resident was never shown a prompt.
  static bool _canReceive(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Fetches the FCM registration token and holds it in [deviceToken].
  ///
  /// Returns null when Firebase is not ready, when FCM has not issued a token,
  /// or when the request fails. None of those is fatal — on iOS the first launch
  /// after install routinely has no APNs token yet, so `getToken` can return
  /// null; the token arrives later on [FirebaseMessaging.onTokenRefresh], which
  /// [_watchForRefresh] listens to so no retry has to be written by hand.
  Future<String?> refreshDeviceToken() async {
    if (!isReady.value) {
      return null;
    }
    try {
      await _noteMissingApnsToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        deviceToken.value = null;
        superPrint(
          'FCM issued no token yet; waiting for a token refresh.',
          title: 'FCM Device Token',
        );
        return null;
      }
      deviceToken.value = token;
      superPrint(
        {'token': token},
        title: 'FCM Device Token',
      );
      _watchForRefresh();
      return token;
    } catch (error) {
      superPrint(
        'Could not fetch the FCM token: $error',
        title: 'FCM Device Token',
      );
      return null;
    }
  }

  /// Records that APNs has not issued a token yet, which is expected on iOS.
  ///
  /// Only worth a log line: FCM still returns its own token, and where it does
  /// not the refresh stream covers it. Nothing here waits, because blocking on
  /// APNs would hold up the signed-in resident for a platform detail.
  Future<void> _noteMissingApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null) {
        superPrint(
          'No APNs token yet (normal on first launch); continuing with FCM.',
          title: 'Firebase Service',
        );
      }
    } catch (error) {
      superPrint(
        'Could not read the APNs token: $error',
        title: 'Firebase Service',
      );
    }
  }

  /// Keeps [deviceToken] current after a rotation or a reinstall.
  ///
  /// Subscribed once, lazily, and only while the app is running: this is token
  /// bookkeeping, not message handling — no notification is shown and no
  /// navigation happens.
  void _watchForRefresh() {
    if (_tokenRefreshSubscription != null) {
      return;
    }
    try {
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (token) {
              deviceToken.value = token.isEmpty ? null : token;
              superPrint(
                {'token': token, 'source': 'onTokenRefresh'},
                title: 'FCM Device Token',
              );
            },
            onError: (Object error) {
              superPrint(
                'FCM token refresh failed: $error',
                title: 'FCM Device Token',
              );
            },
          );
    } catch (error) {
      superPrint(
        'Could not listen for token refreshes: $error',
        title: 'FCM Device Token',
      );
    }
  }
}