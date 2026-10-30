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

import '../deep_link_state.dart';
import '../routes/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _loaderController;
  late final Animation<double> _logoScale;
  late final Animation<double> _fade;
  late final List<Animation<double>> _dotScales;
  late final List<Animation<double>> _dotOpacities;

  /// Minimum time the splash is shown so the brand lands, even on fast loads.
  static const Duration _minimumDisplay = Duration(milliseconds: 1400);

  /// Session restore starts with the animation so the network round trip
  /// overlaps the animation instead of being added to it.
  late final Future<AuthSession?> _restore;

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

  /// Sends the resident onward once the splash has shown and the session check
  /// has settled.
  ///
  /// A remembered session means they were signed in on this device, so they go
  /// straight home. That is not taken on trust: the stored tokens are validated
  /// against the backend first, which also renews them if they expired while the
  /// app was closed. Only once that settles does a route change happen, so the
  /// dashboard is never mounted for a session that is about to be rejected.
  Future<void> _continue() async {
    // Both must finish: the animation for the brand, the restore for the truth
    // about the session.
    final results = await Future.wait<Object?>(<Future<Object?>>[
      Future<void>.delayed(_minimumDisplay),
      _restore,
    ]);

    if (!mounted) {
      return;
    }
    final restored = results.last as AuthSession?;
    Get.offNamed(restored == null ? AppRoutes.login : AppRoutes.home);
    openPendingInvoiceIfReady();
  }

  /// Validates the stored session, if there is one, and adopts it on success.
  ///
  /// Returns the session when the resident may go through to the dashboard, and
  /// null when they have to sign in.
  Future<AuthSession?> _restoreSession() async {
    final auth = Get.find<AuthController>();
    final restored = await auth.restoreSession();
    superPrint(restored, title: "Restore Session");
    if (!mounted || restored == null) {
      return null;
    }
    superPrint(restored.displayName, title: "Restore Session Display Name");
    auth.adoptIntoSession(restored);
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
