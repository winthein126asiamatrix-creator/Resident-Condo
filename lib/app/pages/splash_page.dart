import 'dart:async';

import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:test/core/utils/super_print.dart';

import '../../core/constants/app_constants.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_theme_tokens.dart';

import '../../features/auth/domain/entities/auth_session.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';

import '../routes/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _loaderController;
  late final Animation<double> _logoScale;
  late final Animation<double> _fade;
  late final List<Animation<double>> _dotScales;
  late final List<Animation<double>> _dotOpacities;

  /// Minimum time the splash is shown so the brand lands, even on fast loads.
  static const Duration _minimumDisplay = Duration(milliseconds: 1400);

  /// A restore that has not settled by then must not strand the splash.
  static const Duration _restoreTimeout = Duration(seconds: 10);

  /// Session restore starts with the animation so the network round trip
  /// overlaps the animation instead of being added to it.
  late final Future<AuthSession?> _restore;

  /// Guards the destination so the timeout and the real result cannot both
  /// navigate.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoController.forward();

    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    final dotCount = 3;
    _dotScales = List.generate(dotCount, (index) {
      return Tween<double>(begin: 0.6, end: 1.15).animate(
        CurvedAnimation(
          parent: _loaderController,
          curve: Interval(
            index / dotCount,
            (index + 0.6) / dotCount,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
    _dotOpacities = List.generate(dotCount, (index) {
      return Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(
          parent: _loaderController,
          curve: Interval(
            index / dotCount,
            (index + 0.6) / dotCount,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _restore = _restoreSession();
    _continue();
  }

  Future<void> _continue() async {
    List<Object?>? results;
    try {
      results = await Future.wait<Object?>(<Future<Object?>>[
        Future<void>.delayed(_minimumDisplay),
        _restore,
      ]).timeout(_restoreTimeout);
    } on Object {
      // A failing or never-settling restore must not leave the splash loading
      // forever. A cached session was already adopted before this point; with
      // none, sign-in is the secure destination.
      results = null;
    }

    if (!mounted || _settled) {
      return;
    }
    _settled = true;
    _finishRestore(results == null ? null : results.last as AuthSession?);
  }

  /// Routes away from the splash once the restore attempt settles.
  void _finishRestore(AuthSession? restored) {
    // The splash may have been replaced while a restore was settling; its old
    // result must not navigate the new flow.
    if (!mounted || Get.currentRoute != AppRoutes.splash) {
      return;
    }
    Get.offNamed(restored == null ? AppRoutes.login : AppRoutes.home);
  }

  Future<AuthSession?> _restoreSession() async {
    final auth = Get.find<AuthController>();
    final restored = await auth.restoreSession();
    superPrint(restored, title: "Restore Session");
    if (!mounted || restored == null || Get.currentRoute != AppRoutes.splash) {
      return null;
    }
    superPrint(restored.displayName, title: "Restore Session Display Name");
    await auth.adoptIntoSession(restored);
    if (restored.unverified) {
      // The cached profile is enough to enter the app. Confirm it in the
      // background; a temporary failure leaves it unverified, and a rejected
      // session follows the normal sign-out flow.
      unawaited(auth.revalidateSession());
    }
    return restored;
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand mark in a soft brand-tinted card with a gentle shadow.
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: tokens.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: tokens.cardShadow,
                  ),
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/images/condo-phone-app-icon-hexagon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                24.h.heightBox(),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                8.h.heightBox(),
                Text(
                  'Welcome home',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                40.h.heightBox(),
                _BrandDotsLoader(
                  color: tokens.brand,
                  controller: _loaderController,
                  dotScales: _dotScales,
                  dotOpacities: _dotOpacities,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern brand-colored dot pulse loader used on the splash screen.
class _BrandDotsLoader extends StatelessWidget {
  const _BrandDotsLoader({
    required this.color,
    required this.controller,
    required this.dotScales,
    required this.dotOpacities,
  });

  final Color color;
  final AnimationController controller;
  final List<Animation<double>> dotScales;
  final List<Animation<double>> dotOpacities;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return _DotPulse(
                scale: dotScales[index],
                opacity: dotOpacities[index],
                color: color,
              );
            },
          );
        }),
      ),
    );
  }
}

/// Single pulsing dot driven by the splash loader animations.
class _DotPulse extends StatelessWidget {
  const _DotPulse({
    required this.scale,
    required this.opacity,
    required this.color,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.value,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
