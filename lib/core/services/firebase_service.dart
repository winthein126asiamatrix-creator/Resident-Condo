import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'firebase_options_selector.dart';
import '../utils/super_print.dart';

class FirebaseService extends GetxService {
  /// The channel every ordinary condo notice goes to.
  ///
  /// Untouched, deliberately: its ID, name, importance and sound are what a
  /// resident already has in Android Settings, and Android ignores changes to an
  /// existing channel's importance and sound anyway.
  static const String androidChannelId = 'condo_notifications';

  static const String androidChannelName = 'Condo notifications';

  static const String androidAnnouncementChannelId =
      'announcement_notifications';

  static const String androidAnnouncementChannelName =
      'Announcement Notification Channel';

  static const String typeDataKey = 'type';

  static const int _rememberedMessageLimit = 50;

  final isReady = false.obs;

  final deviceToken = RxnString();

  /// The last notification permission the app asked for or observed.
  final permissionStatus = Rxn<AuthorizationStatus>();

  final pendingNotificationTap = Rxn<RemoteMessage>();

  /// The in-flight (or completed) initialisation, so a second call joins the
  /// first instead of starting a competing `Firebase.initializeApp`.
  Future<void>? _initialising;

  bool _permissionRequested = false;

  bool _androidPermissionRequested = false;

  bool _handlersAttached = false;

  StreamSubscription<String>? _tokenRegistrationSubscription;

  Completer<String?>? _registrationCompleter;

  FlutterLocalNotificationsPlugin? _localNotifications;

  final _shownMessages = <String>{};
  final _handledTaps = <String>{};

  final _messageByNotificationId = <int, RemoteMessage>{};

  Future<void> initialize() {
    return _initialising ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptionsSelector.currentPlatform,
      );
      isReady.value = true;
      superPrint('Firebase initialised', title: 'Firebase Service');
    } catch (error) {
      // Unsupported desktop targets and a missing platform config land here.
      isReady.value = false;
      superPrint(
        'Firebase initialisation failed: $error',
        title: 'Firebase Service',
      );
      return;
    }
    await _prepareLocalNotifications();
    await _attachMessageHandlers();
    await logInstallationId();
  }

  Future<String?> logInstallationId() async {
    if (!isReady.value) {
      return null;
    }
    try {
      final installationId = await FirebaseInstallations.instance.getId();
      superPrint(
        installationId,
        title: 'Firebase Installation ID (paste into In-App Messaging test)',
      );
      return installationId;
    } catch (error) {
      superPrint(
        'Could not read the Firebase Installation ID: $error',
        title: 'Firebase Service',
      );
      return null;
    }
  }

  @override
  void onClose() {
    _tokenRegistrationSubscription?.cancel();
    _tokenRegistrationSubscription = null;
    _registrationCompleter = null;
    _messageByNotificationId.clear();
    _shownMessages.clear();
    _handledTaps.clear();
    super.onClose();
  }

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
      await _requestAndroidNotificationPermission();
      superPrint(
        'Notification permission is ${settings.authorizationStatus.name}; '
        'no FCM token requested.',
        title: 'Firebase Service',
      );
      return;
    }
    await refreshDeviceToken();
  }   

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

 
  Future<void> _requestAndroidNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _androidPermissionRequested) {
      return;
    }
    _androidPermissionRequested = true;
    try {
      final granted = await _localNotifications
          ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      superPrint(
        'POST_NOTIFICATIONS granted: ${granted ?? 'unknown'}',
        title: 'Firebase Service',
      );
    } catch (error) {
      superPrint(
        'Could not request POST_NOTIFICATIONS: $error',
        title: 'Firebase Service',
      );
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

  Future<String?> refreshDeviceToken() async {
    if (!isReady.value) {
      return null;
    }
    try {
      await _noteMissingApnsToken();
      // The installed firebase_messaging version registers the app instance
      // and delivers its registration id through [onRegistered].
      _watchForRegistration();
      final completer = Completer<String?>();
      _registrationCompleter = completer;
      await FirebaseMessaging.instance.register();
      final token = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      _registrationCompleter = null;
      if (token == null || token.isEmpty) {
        deviceToken.value = null;
        superPrint(
          'FCM issued no registration id yet; waiting for registration.',
          title: 'FCM Device Token',
        );
        return null;
      }
      deviceToken.value = token;
      superPrint({'token': token}, title: 'FCM Device Token');
      return token;
    } catch (error) {
      superPrint(
        'Could not fetch the FCM token: $error',
        title: 'FCM Device Token',
      );
      return null;
    }
  }

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

  void _watchForRegistration() {
    if (_tokenRegistrationSubscription != null) {
      return;
    }
    try {
      _tokenRegistrationSubscription = FirebaseMessaging.instance.onRegistered
          .listen(
            (token) {
              deviceToken.value = token.isEmpty ? null : token;
              superPrint({
                'token': token,
                'source': 'onRegistered',
              }, title: 'FCM Device Token');
              final completer = _registrationCompleter;
              if (completer != null && !completer.isCompleted) {
                completer.complete(token);
              }
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

  Future<void> _attachMessageHandlers() async {
    if (_handlersAttached) {
      return;
    }
    _handlersAttached = true;
    final messaging = FirebaseMessaging.instance;
    try {
      // Foreground. The system posts nothing here, so a local notification is
      // raised instead (see _showForegroundNotification).
      FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
        onError: (Object error) {
          superPrint(
            'Foreground message stream failed: $error',
            title: 'Firebase Message',
          );
        },
      );

      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) {
          _logChannelDecision(
            message,
            state: 'background tap (onMessageOpenedApp)',
            selectedChannel: _channelIdFor(message),
          );
          _captureTap(message);
        },
        onError: (Object error) {
          superPrint(
            'Opened-app message stream failed: $error',
            title: 'Firebase Message',
          );
        },
      );

      // A tap that brought a terminated app back to life.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        superPrint(
          'App launched from a notification tap.',
          title: 'Firebase Message',
        );
        _logChannelDecision(
          initial,
          state: 'terminated tap (getInitialMessage)',
          selectedChannel: _channelIdFor(initial),
        );
        _captureTap(initial);
      }
    } catch (error) {
      superPrint(
        'Could not attach the message handlers: $error',
        title: 'Firebase Message',
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    superPrint({
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    }, title: 'FCM message received (foreground)');
    _logChannelDecision(
      message,
      state: 'foreground (onMessage)',
      selectedChannel: _channelIdFor(message),
    );
    unawaited(_showForegroundNotification(message));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final plugin = _localNotifications;
    final notification = message.notification;
    if (plugin == null || notification == null) {
      return;
    }
    final key = _keyOf(message);
    if (!_remember(_shownMessages, key)) {
      return;
    }
    try {
      final id = key.hashCode & 0x7FFFFFFF;
      _messageByNotificationId[id] = message;
      final channelId = _channelIdFor(message);
      await plugin.show(
        id: id,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == androidAnnouncementChannelId
                ? androidAnnouncementChannelName
                : androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
            channelShowBadge: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      superPrint({
        'notificationId': id,
        'title': notification.title,
        'channel': channelId,
      }, title: 'FCM shown in foreground');
    } catch (error) {
      superPrint(
        'Could not show the foreground notification: $error',
        title: 'FCM Message',
      );
    }
  }

  String _channelIdFor(RemoteMessage message) {
    final configured = message.notification?.android?.channelId?.trim();
    if (configured == androidAnnouncementChannelId ||
        configured == androidChannelId) {
      return configured!;
    }
    // final type = message.data[typeDataKey];
    // if (type != null && _announcementTypes.contains(type.trim())) {
    //   return androidAnnouncementChannelId;
    // }
    return androidChannelId;
  }

  void _logChannelDecision(
    RemoteMessage message, {
    required String state,
    String? selectedChannel,
  }) {
    superPrint({
      'handledBy': state,
      'data': message.data,
      'typeDataKey': typeDataKey,
      'type': message.data[typeDataKey],
      'payloadChannelId': message.notification?.android?.channelId,
      'selectedChannelId': selectedChannel,
      'detected': _describeChannelSelection(message),
    }, title: 'FCM channel routing');
  }

  /// A short, human-readable account of how [_channelIdFor] decided.
  String _describeChannelSelection(RemoteMessage message) {
    final configured = message.notification?.android?.channelId?.trim();
    if (configured == androidAnnouncementChannelId) {
      return 'announcement (payload channel)';
    }
    if (configured == androidChannelId) {
      return 'condo (payload channel)';
    }
    if (configured != null && configured.isNotEmpty) {
      return 'unknown channel "$configured" ignored, fell through';
    }
    final type = message.data[typeDataKey];
    if (type != null && androidAnnouncementChannelId == type.trim()) {
      return 'announcement (data type "$type")';
    }
    return 'condo (default)';
  }

  /// A tap on one of the local notifications this app posted.
  void _onLocalNotificationTapped(NotificationResponse response) {
    final id = response.id;
    final message = id == null ? null : _messageByNotificationId[id];
    if (message == null) {
      superPrint(
        'Tapped a notification with no FCM message behind it.',
        title: 'Firebase Message',
      );
      return;
    }
    _logChannelDecision(
      message,
      state: 'local notification tap',
      selectedChannel: _channelIdFor(message),
    );
    _captureTap(message);
  }

  void _captureTap(RemoteMessage message) {
    if (!_remember(_handledTaps, _keyOf(message))) {
      return;
    }
    superPrint({
      'messageId': message.messageId,
      'data': message.data,
    }, title: 'FCM notification tapped');
    pendingNotificationTap.value = message;
  }

  /// Clears [pendingNotificationTap] once the app root has acted on it.
  void consumePendingNotificationTap() {
    pendingNotificationTap.value = null;
  }

  static String _keyOf(RemoteMessage message) {
    return message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch}:${message.hashCode}';
  }

  bool _remember(Set<String> seen, String key) {
    if (!seen.add(key)) {
      return false;
    }
    if (seen.length > _rememberedMessageLimit) {
      seen.remove(seen.first);
    }
    return true;
  }

  Future<void> _prepareLocalNotifications() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final initialized = await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );
      if (initialized != true) {
        superPrint(
          'Local notifications did not initialise; foreground messages will '
          'only be logged.',
          title: 'Firebase Service',
        );
        return;
      }
      _localNotifications = plugin;
      await _ensureAndroidChannels();
    } catch (error) {
      superPrint(
        'Local notifications unavailable: $error',
        title: 'Firebase Service',
      );
    }
  }

  Future<void> _ensureAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final android = _localNotifications
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }
    try {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          androidChannelId,
          androidChannelName,
          description: 'Maintenance, payments, visitors and gate notices.',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          androidAnnouncementChannelId,
          androidAnnouncementChannelName,
          description: 'Building-wide announcements from management.',
          importance: Importance.high,
        ),
      );
    } catch (error) {
      superPrint(
        'Could not create the Android channels: $error',
        title: 'Firebase Service',
      );
    }
  }
}
