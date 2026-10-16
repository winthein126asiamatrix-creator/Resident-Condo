import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import 'firebase_background_handler.dart';
import 'firebase_service.dart';

/// Registers the shared Firebase layer.
///
/// App scoped and permanent, for the same reason the HTTP client is: there is one
/// Firebase app and one messaging subscription, and a second `Firebase
/// initializeApp` would throw.
///
/// [register] awaits initialisation rather than leaving it to a background
/// future, because `main` has to be able to promise that Messaging is safe to
/// touch by the first frame, and because a tap that launched the app is read by
/// `getInitialMessage` during that initialisation. The service is put in the
/// container first, so a failed initialisation still leaves a registered service
/// whose methods no-op, rather than a missing one.
abstract final class FirebaseBinding extends Bindings {
  static bool _backgroundHandlerRegistered = false;

  /// Registers the service and initialises Firebase, unless already registered.
  static Future<void> register() async {
    if (Get.isRegistered<FirebaseService>()) {
      return;
    }
    _registerBackgroundHandler();
    final service = FirebaseService();
    Get.put<FirebaseService>(service, permanent: true);
    await service.initialize();
  }

  /// Registers the background isolate handler.
  ///
  /// Must happen before `Firebase.initializeApp`, which is why it is here rather
  /// than inside the service: a message that arrives while the app is not
  /// running starts a fresh isolate, and the plugin only routes it to a handler
  /// that was registered before the SDK was brought up. Registering twice is
  /// harmless but noisy, hence the flag.
  static void _registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) {
      return;
    }
    _backgroundHandlerRegistered = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Satisfies [Bindings] so the layer can also be attached to a route.
  ///
  /// Fire and forget, for the same reason `ApiBinding` can be attached to a
  /// route: initialisation belongs to startup, and a route that arrives mid
  /// initialisation simply joins it through [FirebaseService.initialize].
  @override
  void dependencies() {
    unawaited(register());
  }
}