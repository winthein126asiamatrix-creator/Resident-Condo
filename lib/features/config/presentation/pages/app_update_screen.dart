import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../controllers/app_config_controller.dart';

class AppUpdateScreen extends StatelessWidget {
  const AppUpdateScreen({required this.mandatory, super.key});

  final bool mandatory;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppConfigController>();
    final tokens = AppThemeTokens.of(context);
    final installed = controller.installedVersion.value ?? 'Unknown';
    final latest = controller.versionConfig?.latest ?? 'the latest version';

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !mandatory) controller.dismissOptionalUpdate();
      },
      child: Scaffold(
        key: Key(
          mandatory ? 'mandatory-update-screen' : 'optional-update-screen',
        ),
        backgroundColor: tokens.canvas,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _UpdateIllustration(mandatory: mandatory),
                        32.h.heightBox(),
                        Text(
                          mandatory ? 'Update Required' : 'Update Available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                        12.h.heightBox(),
                        Text(
                          mandatory
                              ? 'A new version of Matrix Condo  is required '
                                    'to continue. Please update the app to get '
                                    'the latest improvements and fixes.'
                              : 'A newer version of Matrix Condo is '
                                    'available. Update now to enjoy the latest '
                                    'improvements.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            height: 1.5,
                            color: tokens.mutedStrong,
                          ),
                        ),
                        28.h.heightBox(),
                        _VersionCard(installed: installed, latest: latest),
                        if (mandatory) ...[18.h.heightBox(), _RequiredNotice()],
                        36.h.heightBox(),
                        AppPrimaryAction(
                          key: Key(
                            mandatory
                                ? 'mandatory-update-button'
                                : 'optional-update-button',
                          ),
                          label: 'Update Now',
                          icon: Icons.open_in_new_rounded,
                          onPressed: controller.hasUpdateTarget
                              ? () => _openStore(context, controller)
                              : null,
                        ),
                        if (!controller.hasUpdateTarget) ...[
                          10.h.heightBox(),
                          Text(
                            'No update link is available. Please try again later '
                            'or update from your store.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                        if (!mandatory) ...[
                          12.h.heightBox(),
                          TextButton(
                            key: const Key('optional-update-later'),
                            onPressed: () => controller.dismissOptionalUpdate(),
                            child: Text(
                              'Later',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: tokens.mutedStrong,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(
    BuildContext context,
    AppConfigController controller,
  ) async {
    final opened = await controller.openUpdateUrl();
    if (!opened && context.mounted) {
      Get.snackbar(
        'Unable to open the app store',
        'The update link is unavailable. Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class _UpdateIllustration extends StatelessWidget {
  const _UpdateIllustration({required this.mandatory});

  final bool mandatory;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [tokens.brand, tokens.brand.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: tokens.heroShadow,
      ),
      child: Icon(
        mandatory
            ? Icons.lock_outline_rounded
            : Icons.system_update_alt_rounded,
        size: 62,
        color: tokens.onBrand,
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.installed, required this.latest});

  final String installed;
  final String latest;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          _VersionRow(label: 'Installed version', value: installed),
          14.h.heightBox(),
          Divider(height: 1, color: tokens.border),
          14.h.heightBox(),
          _VersionRow(label: 'Latest available', value: latest),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: tokens.muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: tokens.ink,
          ),
        ),
      ],
    );
  }
}

class _RequiredNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tokens.brandBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: tokens.brand),
          10.w.widthBox(),
          Expanded(
            child: Text(
              'Updating is required to continue using Matrix Condo.',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppUpdateRoute extends StatefulWidget {
  const AppUpdateRoute({super.key});

  @override
  State<AppUpdateRoute> createState() => _AppUpdateRouteState();
}

class _AppUpdateRouteState extends State<AppUpdateRoute> {
  bool _redirecting = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppConfigController>();
    return Obx(() {
      if (controller.updateRequirement == UpdateRequirement.mandatory) {
        return const AppUpdateScreen(mandatory: true);
      }
      if (controller.updateRequirement == UpdateRequirement.optional &&
          !controller.optionalUpdateDismissed.value) {
        return const AppUpdateScreen(mandatory: false);
      }
      if (!_redirecting) {
        _redirecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.currentRoute == AppRoutes.appUpdate) {
            Get.offAllNamed(AppRoutes.home);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    });
  }
}
