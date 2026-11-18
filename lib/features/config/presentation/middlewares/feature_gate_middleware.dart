import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/condo_config.dart';
import '../controllers/condo_config_controller.dart';

class FeatureGateMiddleware extends GetMiddleware {
  FeatureGateMiddleware(this.feature);

  final CondoFeature feature;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<CondoConfigController>()) return null;
    final controller = Get.find<CondoConfigController>();
    if (controller.config.value == null) return null;
    if (controller.isFeatureEnabled(feature)) return null;
    return RouteSettings(
      name: AppRoutes.featureUnavailable,
      arguments: feature.label,
    );
  }
}
