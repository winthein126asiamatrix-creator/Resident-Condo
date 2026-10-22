import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/firebase_binding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show appFlavor;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
   final envFile = switch (appFlavor) {
    'dev' => '.env.dev',
    'prod' => '.env.prod',
    _ => throw StateError(
        'Unknown app flavor: $appFlavor. '
        'Run with --flavor dev or --flavor prod.',
      ),
  };

  await dotenv.load(fileName: envFile);

  await FirebaseBinding.register();

  final preferences = await SharedPreferences.getInstance();
  final savedCode = preferences.getString('app.locale');
  final initialLocale = (savedCode == 'my' || savedCode == 'zh')
      ? Locale(savedCode!)
      : const Locale('en');

  runApp(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => child!,
      child: CondoResidentApp(initialLocale: initialLocale),
    ),
  );
}
