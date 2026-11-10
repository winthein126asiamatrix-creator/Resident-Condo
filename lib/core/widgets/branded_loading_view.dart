import 'dart:math' as math;

import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';

import '../theme/app_theme_tokens.dart';

class BrandedLoadingView extends StatefulWidget {
  const BrandedLoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  State<BrandedLoadingView> createState() => _BrandedLoadingViewState();
}

class _BrandedLoadingViewState extends State<BrandedLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                  'assets/images/condo-phone-app-icon-hexagon.png',
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
              Text(widget.message, style: TextStyle(color: tokens.muted)),
              20.h.heightBox(),
              SizedBox(
                height: 16,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final delay = index * 0.2;
                        final progress = (_controller.value - delay) % 1.0;
                        final wave =
                            (math.sin(progress * math.pi * 2) + 1) / 2;
                        final scale = 0.6 + wave * 0.4;
                        final opacity = 0.35 + wave * 0.65;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 10.w,
                                height: 10.w,
                                decoration: BoxDecoration(
                                  color: tokens.brand,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
