import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../controllers/app_config_controller.dart';

class UpdateGateMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (route == AppRoutes.appUpdate) return null;
    if (!Get.isRegistered<AppConfigController>()) return null;
    final controller = Get.find<AppConfigController>();
    if (controller.maintenanceActive) return null;
    if (controller.updateRequirement != UpdateRequirement.mandatory) {
      return null;
    }
    return const RouteSettings(name: AppRoutes.appUpdate);
  }
}
