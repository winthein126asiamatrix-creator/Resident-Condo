import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../domain/entities/app_config.dart';
import '../controllers/app_config_controller.dart';

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
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            _MandatoryUpdateScreen(controller: controller),
          ],
        );
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

class _MandatoryUpdateScreen extends StatelessWidget {
  const _MandatoryUpdateScreen({required this.controller});

  final AppConfigController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final installed = controller.installedVersion.value ?? 'Unknown';
    final latest = controller.versionConfig?.latest ?? '—';
    final canUpdate = controller.hasUpdateTarget;
    return Scaffold(
      key: const Key('mandatory-update-screen'),
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
                    icon: Icons.system_update_alt_rounded,
                    color: tokens.brand,
                    background: tokens.brandTint,
                  ),
                  24.h.heightBox(),
                  Text(
                    'Update required',
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
                    'This version of the app is no longer supported. '
                    'Please update to the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 14.5.sp,
                      height: 1.45,
                    ),
                  ),
                  24.h.heightBox(),
                  _VersionCard(
                    installed: installed,
                    latest: latest,
                    accent: tokens.brand,
                    surface: tokens.surface,
                    border: tokens.border,
                    muted: tokens.muted,
                    ink: tokens.ink,
                  ),
                  24.h.heightBox(),
                  AppPrimaryAction(
                    key: const Key('mandatory-update-button'),
                    label: 'Update now',
                    icon: Icons.open_in_new_rounded,
                    onPressed: canUpdate
                        ? () => _openStore(context, tokens)
                        : null,
                  ),
                  if (!canUpdate) ...[
                    14.h.heightBox(),
                    Text(
                      'Open your app store to update the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.muted, fontSize: 12.sp),
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

  Future<void> _openStore(BuildContext context, AppThemeTokens tokens) async {
    final opened = await controller.openUpdateUrl();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surface,
        content: Text(
          'Could not open the app store. Please update manually.',
          style: TextStyle(color: tokens.ink),
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

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.installed,
    required this.latest,
    required this.accent,
    required this.surface,
    required this.border,
    required this.muted,
    required this.ink,
  });

  final String installed;
  final String latest;
  final Color accent;
  final Color surface;
  final Color border;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _VersionRow(
            label: 'Installed version',
            value: installed,
            muted: muted,
            ink: ink,
          ),
          Divider(height: 1, color: border),
          _VersionRow(
            label: 'Latest version',
            value: latest,
            muted: muted,
            ink: accent,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    required this.muted,
    required this.ink,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color muted;
  final Color ink;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: muted, fontSize: 13.sp),
            ),
          ),
          12.w.widthBox(),
          Text(
            value,
            style: TextStyle(
              color: ink,
              fontSize: 14.5.sp,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
