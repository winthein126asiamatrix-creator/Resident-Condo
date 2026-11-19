import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../domain/entities/app_config.dart';
import '../controllers/app_config_controller.dart';
import 'app_update_screen.dart';

class AppConfigGate extends StatelessWidget {
  const AppConfigGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppConfigController>()) {
      return child;
    }
    final controller = Get.find<AppConfigController>();
    return Obx(() {
      if (controller.maintenanceActive) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            _MaintenanceScreen(maintenance: controller.maintenance),
          ],
        );
      }
      if (controller.updateRequirement == UpdateRequirement.mandatory) {
        return const AppUpdateScreen(mandatory: true);
      }
      if (controller.updateRequirement == UpdateRequirement.optional &&
          !controller.optionalUpdateDismissed.value) {
        return const AppUpdateScreen(mandatory: false);
      }
      return child;
    });
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.maintenance});

  final AppMaintenanceConfig? maintenance;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final message = maintenance?.message?.trim();
    final endsAt = maintenance?.endsAt;
    return Scaffold(
      key: const Key('maintenance-screen'),
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BlockingIcon(
                    icon: Icons.engineering_rounded,
                    color: tokens.brand,
                    background: tokens.brandTint,
                  ),
                  24.h.heightBox(),
                  Text(
                    'Scheduled maintenance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  12.h.heightBox(),
                  Text(
                    message == null || message.isEmpty
                        ? 'The resident app is temporarily unavailable while '
                              'the management team performs maintenance. '
                              'Please check back shortly.'
                        : message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 14.5.sp,
                      height: 1.45,
                    ),
                  ),
                  if (endsAt != null) ...[
                    24.h.heightBox(),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 20,
                            color: tokens.brand,
                          ),
                          12.w.widthBox(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expected back',
                                  style: TextStyle(
                                    color: tokens.muted,
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                3.h.heightBox(),
                                Text(
                                  AppDates.formatDateTime(endsAt.toLocal()),
                                  style: TextStyle(
                                    color: tokens.ink,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockingIcon extends StatelessWidget {
  const _BlockingIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Icon(icon, size: 44, color: color),
    );
  }
}
