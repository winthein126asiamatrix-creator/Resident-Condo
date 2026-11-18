import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_state_message.dart';

class FeatureUnavailablePage extends StatelessWidget {
  const FeatureUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final feature = Get.arguments is String ? Get.arguments as String : null;
    return Scaffold(
      appBar: AppDetailAppBar(title: feature ?? 'Not available'),
      body: SafeArea(
        child: AppStateMessage(
          title: 'Not available',
          message: feature == null
              ? 'This service is not available for your condominium.'
              : '$feature is not available for your condominium.',
          icon: Icons.lock_outline_rounded,
          actionLabel: 'Go back',
          onAction: Get.back<void>,
        ),
      ),
    );
  }
}
