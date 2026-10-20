import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import 'firebase_background_handler.dart';
import 'firebase_service.dart';

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

  static void _registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) {
      return;
    }
    _backgroundHandlerRegistered = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  @override
  void dependencies() {
    unawaited(register());
  }
}
