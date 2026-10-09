import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_binding.dart';
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
/// The [Obx] is the whole integration: the theme is built from the controller's
/// *applied* preference, so only "Apply Theme" — never a preview — rebuilds
/// `GetMaterialApp` and repaints every mounted screen at once.
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
    // App scoped, so they are registered before the first frame. The binding is
    // idempotent and the routes that need them run it again harmlessly.
    ApiBinding.register();
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
