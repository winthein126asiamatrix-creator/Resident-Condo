import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../controllers/app_config_controller.dart';

class OptionalUpdateBanner extends StatelessWidget {
  const OptionalUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppConfigController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<AppConfigController>();
    return Obx(() {
      if (!controller.shouldShowOptionalUpdate) {
        return const SizedBox.shrink();
      }
      final tokens = AppThemeTokens.of(context);
      final latest = controller.versionConfig?.latest;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          key: const Key('optional-update-banner'),
          padding: EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: tokens.brandTint,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: tokens.brandBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: tokens.brand,
                size: 22,
              ),
              12.w.widthBox(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update available',
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    2.h.heightBox(),
                    Text(
                      latest == null
                          ? 'A newer version of the app is ready.'
                          : 'Version $latest is ready to install.',
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              8.w.widthBox(),
              TextButton(
                onPressed: controller.dismissOptionalUpdate,
                style: TextButton.styleFrom(
                  minimumSize: Size(0, 36),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: tokens.muted,
                  textStyle: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () async {
                  final opened = await controller.openUpdateUrl();
                  if (opened || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Could not open the app store. Please update manually.',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: Size(0, 36),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: tokens.brand,
                  textStyle: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      );
    });
  }
}
