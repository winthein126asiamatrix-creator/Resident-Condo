import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options_selector.dart';
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptionsSelector.currentPlatform,
      );
    }
  } catch (_) {
    // Nothing in this isolate can recover from a failed init, and a throw here
    // would only be reported as a background crash with no context.
  }
}