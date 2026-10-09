import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../routes/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  /// How long the brand is shown regardless of how fast the session check is.
  static const Duration _minimumDisplay = Duration(milliseconds: 1600);

  /// The session check, started as soon as the splash appears.
  ///
  /// Kicked off here rather than after the animation so the network round trip
  /// overlaps the animation instead of being added to it.
  late final Future<AuthSession?> _restore;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
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
  }

  /// Validates the stored session, if there is one, and adopts it on success.
  ///
  /// Returns the session when the resident may go through to the dashboard, and
  /// null when they have to sign in.
  Future<AuthSession?> _restoreSession() async {
    final auth = Get.find<AuthController>();
    final restored = await auth.restoreSession();
    if (!mounted || restored == null) {
      return null;
    }
    auth.adoptIntoSession(restored);
    return restored;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.brand,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 112,
                    height: 112,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.onBrand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
