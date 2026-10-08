import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../features/appearance/presentation/bindings/appearance_binding.dart';
import '../features/appearance/presentation/controllers/appearance_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

/// The application root.
///
/// The theme is built from [AppearanceController], which is the single source of
/// truth for the resident's brand colour. Registering it here, before the first
/// build, means the saved colour is applied on the very first frame rather than
/// flashing the default and correcting a moment later.
///
/// The [Obx] is the whole integration: a change to the controller rebuilds
/// `GetMaterialApp` with a new `ThemeData`, which repaints every mounted screen,
/// including the ones further down the navigation stack.
class CondoResidentApp extends StatefulWidget {
  const CondoResidentApp({super.key});

  @override
  State<CondoResidentApp> createState() => _CondoResidentAppState();
}

class _CondoResidentAppState extends State<CondoResidentApp> {
  late final AppearanceController _appearance;

  @override
  void initState() {
    super.initState();
    // Idempotent: the Appearance screen's own route binding is a no-op once
    // this has run.
    AppearanceBinding().dependencies();
    _appearance = Get.find<AppearanceController>();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: _appearance.theme,
        darkTheme: _appearance.darkTheme,
        themeMode: _appearance.themeMode,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );
  }
}