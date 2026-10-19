
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../../firebase_options.dart' as prod;
import '../../firebase_options_dev.dart' as dev;

abstract final class FirebaseOptionsSelector {
  static FirebaseOptions get currentPlatform {
    switch (appFlavor) {
      case 'dev':
        return dev.DefaultFirebaseOptions.currentPlatform;

      case 'prod':
        return prod.DefaultFirebaseOptions.currentPlatform;

      default:
        throw StateError(
          'Unknown app flavor: $appFlavor. '
          'Run with --flavor dev or --flavor prod.',
        );
    }
  }
}
