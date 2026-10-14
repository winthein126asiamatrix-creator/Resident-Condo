import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import '../constants/app_constants.dart';


import '../theme/app_theme_tokens.dart';

class BrandedLoadingView extends StatelessWidget {
  BrandedLoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22.r),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brand.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: Offset(0, 8),
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
              20.h.heightBox(),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              6.h.heightBox(),
              Text(message, style: TextStyle(color: tokens.muted)),
              20.h.heightBox(),
              SizedBox(
                width: 132,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(4.r)),
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
