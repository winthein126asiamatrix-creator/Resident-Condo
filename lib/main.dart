import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/firebase_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase first: the messaging permission and the device token are only
  // meaningful once the SDK is up, and both are wanted as early as the app can
  // get them. Nothing after this line blocks on Firebase messaging.
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
