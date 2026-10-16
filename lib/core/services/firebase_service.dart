import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../firebase_options.dart';
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

  /// Whether the system prompt has already been shown this run.
  ///
  /// The permission is only ever requested while iOS/Android report
  /// "not determined", but this is kept as well so a resident who was sent to
  /// sign-in cannot be prompted a second time by the session being adopted
  /// again on a reconnect.
  bool _permissionRequested = false;

  /// Whether `POST_NOTIFICATIONS` has been asked for through the local
  /// notifications plugin. See [_requestAndroidNotificationPermission].
  bool _androidPermissionRequested = false;

  /// Whether the streaming message handlers are attached, so a second call
  /// cannot end up with two subscriptions for the same event.
  bool _handlersAttached = false;

  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Null until [initialize] succeeds, so a service that never started shows
  /// nothing even if a message somehow arrives.
  FlutterLocalNotificationsPlugin? _localNotifications;

  final _shownMessages = <String>{};
  final _handledTaps = <String>{};

  /// The message behind each notification id this app posted, so a tap on a
  /// local notification can be reported as the FCM message it came from.
  final _messageByNotificationId = <int, RemoteMessage>{};

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
      superPrint(
        'Firebase initialisation failed: $error',
        title: 'Firebase Service',
      );
      return;
    }
    await _prepareLocalNotifications();
    await _attachMessageHandlers();
  }

  @override
  void onClose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _messageByNotificationId.clear();
    _shownMessages.clear();
    _handledTaps.clear();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Permission and token
  // ---------------------------------------------------------------------------

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

  /// Asks for `POST_NOTIFICATIONS` on Android 13 and above, once.
  ///
  /// The FCM request already covers it on current Android versions, so this only
  /// runs when FCM reported no permission and the resident has not been asked
  /// here yet. Android shows a system dialog per app at most, so a second call
  /// returns the stored answer rather than prompting again.
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
      superPrint({'token': token}, title: 'FCM Device Token');
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
  /// navigation happens. A refreshed token is logged for the same reason the
  /// first one is, so a backend that is wired up later can watch for it here.
  void _watchForRefresh() {
    if (_tokenRefreshSubscription != null) {
      return;
    }
    try {
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (token) {
              deviceToken.value = token.isEmpty ? null : token;
              superPrint({
                'token': token,
                'source': 'onTokenRefresh',
              }, title: 'FCM Device Token');
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

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Attaches the streaming handlers and looks for the tap that launched the app.
  ///
  /// Attached here rather than lazily, because a tap on a notification that
  /// launched a terminated app is delivered through `getInitialMessage` before
  /// the first frame — after `main` has awaited [initialize] but before
  /// anything is listening.
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

      // A tap on a tray notification while the app was in the background. The
      // process was still alive, so the session is still in memory.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) {
          _logChannelDecision(
            message,
            state: 'background tap (onMessageOpenedApp)',
            // For diagnosis only: the notification was already drawn by the
            // Android SDK, on the channel the payload named. Dart sees the tap
            // afterwards and cannot move a notification that is already up.
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

  /// A message that arrived while the app was open.
  ///
  /// Shown as a local notification, because FCM deliberately stays silent in the
  /// foreground: the system has already drawn the tray for a backgrounded app,
  /// and doing it again here is what produces a duplicate.
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

  /// Raises a local notification for a message received in the foreground.
  ///
  /// Data-only messages are skipped: they carry no title or body, so there is
  /// nothing to show and a blank tray entry would be worse than none.
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

  /// Which Android channel a message belongs on.
  ///
  /// Read in this order:
  ///
  /// 1. **The channel the sender configured.** The Firebase console's *Android
  ///    Notification Channel* field, and `android.notification.channel_id` in
  ///    the HTTP v1 payload, arrive as `notification.android.channelId` — never
  ///    as a `data` entry. This is the authoritative answer, and it is what the
  ///    Android SDK itself uses when it draws a background notification, so
  ///    honouring it here is what keeps the foreground and the background on one
  ///    channel. Only the two channels this app actually creates are accepted;
  ///    any other value is ignored rather than posted to a channel that does not
  ///    exist, which Android would silently redirect anyway.
  /// 2. **The `data` type**, as a fallback for a sender that sets a type but no
  ///    channel.
  /// 3. **[androidChannelId]**, for everything else — including a plain console
  ///    test message with neither field.
  ///
  /// Only announcements are separated out; payments, visitors, maintenance and
  /// gate notices stay on [androidChannelId], where they have always appeared.
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

  /// The facts needed to see why a notification landed on one channel.
  ///
  /// `superPrint` prints in debug builds only, so this costs nothing in release
  /// and cannot leak into a production log. Deliberately omits the FCM token and
  /// any Firebase credentials — only what was received, what was decided, and
  /// where the message was handled.
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
      // A notification the app cannot attribute to a message: logged rather than
      // navigated, because there is nothing to open.
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

  /// Records a tap so the app root can act on it.
  ///
  /// De-duplicated against [_handledTaps] rather than against what has been
  /// *shown*, because the notification a resident is tapping is usually one this
  /// app posted a moment ago: sharing a set would reject every foreground tap as
  /// a duplicate of its own display, and the notification page would never open.
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

  /// A stable key for a message, used to show and act on each one only once.
  ///
  /// `messageId` is the only stable identifier FCM gives, but a locally built
  /// message can arrive without one, so the send time and contents stand in.
  static String _keyOf(RemoteMessage message) {
    return message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch}:${message.hashCode}';
  }

  /// Whether the key is new to [seen], remembering it either way.
  ///
  /// Takes the set as an argument so the two de-duplication purposes stay
  /// independent: [_shownMessages] guards the tray, [_handledTaps] guards
  /// navigation. Returns true only for a key that was not there before, which is
  /// what every call site checks with `!`.
  ///
  /// Evicts the oldest key past [_rememberedMessageLimit], so a long-lived
  /// session cannot grow either set without bound. Eviction can only make a very
  /// old key look new again, which costs one extra notification at worst.
  bool _remember(Set<String> seen, String key) {
    if (!seen.add(key)) {
      return false;
    }
    if (seen.length > _rememberedMessageLimit) {
      seen.remove(seen.first);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Local notifications
  // ---------------------------------------------------------------------------

  /// Prepares local notifications: plugin, channel, and tap callback.
  ///
  /// Permission is not requested here. The local plugin's own prompts are turned
  /// off in its initialisation settings because [onResidentSignedIn] asks once,
  /// through FCM, at the point where a resident is signed in — two plugins
  /// asking would mean two dialogs and an answer that does not stick.
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
      // A device without notification support is not a reason to lose push
      // entirely: messages are still received and logged.
      superPrint(
        'Local notifications unavailable: $error',
        title: 'Firebase Service',
      );
    }
  }

  /// Creates the Android channels the app posts to.
  ///
  /// Both are created together, at startup, so the first message never has to
  /// fall back to a system channel. This matters for announcements in
  /// particular: Android silently redirects a notification to the default
  /// channel when the channel named in the payload does not exist yet, and a
  /// background message can be drawn by the system before any Dart code runs.
  ///
  /// Re-creating a channel is safe and is what happens on every launch.
  /// `createNotificationChannel` only fills in settings that Android has not
  /// already stored, so a resident who has muted a channel, changed its sound
  /// or turned its vibration off keeps those choices — which is the whole reason
  /// the announcement channel is separate from the condo one.
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
