import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart' as prod;
import '../../firebase_options_dev.dart' as dev;
import '../config/app_environment.dart';

abstract final class FirebaseOptionsSelector {
  static FirebaseOptions get currentPlatform {
    switch (AppEnvironment.current) {
      case AppEnvironment.dev:
        return dev.DefaultFirebaseOptions.currentPlatform;

      case AppEnvironment.prod:
        return prod.DefaultFirebaseOptions.currentPlatform;
    }
  }
}
