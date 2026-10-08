import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme_tokens.dart';

class BrandedLoadingView extends StatelessWidget {
  const BrandedLoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brand.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(message, style: TextStyle(color: tokens.muted)),
              const SizedBox(height: 20),
              SizedBox(
                width: 132,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  color: tokens.brand,
                  backgroundColor: tokens.brandSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
