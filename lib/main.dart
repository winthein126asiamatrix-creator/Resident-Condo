import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
