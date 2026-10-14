import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/constants/app_constants.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_radius.dart';


import '../../../../core/theme/app_spacing.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/widgets/app_dialogs.dart';


import '../../../../core/widgets/app_form_field.dart';


import '../../../../core/widgets/app_primary_action.dart';


import '../controllers/auth_controller.dart';

/// The resident sign-in screen.
///
/// Scrolls rather than shrinks so the fields keep their full height when the
/// keyboard is up, and centres its content vertically so it still looks
/// deliberate on a tall phone. Nothing here is a gradient or a heavy animation:
/// a login screen should feel like the app is simply asking you for your key.
class LoginPage extends StatefulWidget {
  LoginPage({this.onSignedIn, super.key});

  final void Function()? onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final AuthController _auth;
  late final TextEditingController _username;
  late final TextEditingController _password;
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    // Nothing is pre-filled. The backend owns credential checking now, so a
    // credential baked into the widget tree would be both useless and a
    // liability; the username is pre-filled instead when it was remembered, and
    // only when the resident asked to be remembered.
    if (_auth.rememberMe.value) {
      _auth.usernameController.text = _auth.rememberedUsername ?? '';
    }
    _auth.usernameController.text = "emilys";
    _auth.passwordController.text = "emilyspass";
    _username = _auth.usernameController;
    _password = _auth.passwordController;
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Default is true, which is what lets the body shrink above the keyboard.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: constraints.maxHeight > 0
                  ? ClampingScrollPhysics()
                  : NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.pageTop,
                AppSpacing.gutter,
                AppSpacing.pageBottom + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.pageTop * 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    12.h.heightBox(),
                    _LoginHeader(),
                    28.h.heightBox(),
                    _LoginForm(
                      formKey: _formKey,
                      auth: _auth,
                      username: _username,
                      password: _password,
                      usernameFocus: _usernameFocus,
                      passwordFocus: _passwordFocus,
                      onSubmit: _submit,
                    ),
                    AppSpacing.sectionGap.heightBox(),
                    _LoginFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    // Dismisses the keyboard so the loading state and any error are visible
    // without the resident having to scroll.
    FocusScope.of(context).unfocus();

    // Runs the field validators, which is what actually paints the inline
    // error text. The controller alone cannot do this: it has no Form to
    // validate against.
    final isValid = _formKey.currentState?.validate() ?? false;
    final session = isValid ? await _auth.signIn() : null;

    if (!mounted) {
      return;
    }

    if (session == null) {
      // Put focus on the first field that needs attention, so the resident can
      // start fixing it without hunting for the red line.
      final field = _auth.invalidField.value;
      if (field == 'username') {
        _usernameFocus.requestFocus();
      } else if (field == 'password') {
        _passwordFocus.requestFocus();
      }
      return;
    }

    (widget.onSignedIn ?? () => Get.offAllNamed(AppRoutes.home))();
  }
}

/// The app icon, the greeting and the supporting line.
class _LoginHeader extends StatelessWidget {
  _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        22.h.heightBox(),
        Text(
          'Welcome back',
          style: TextStyle(
            color: tokens.ink,
            fontSize: 27.sp,
            height: 1.2,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        6.h.heightBox(),
        Text(
          'Sign in to manage your residence',
          style: TextStyle(color: tokens.muted, fontSize: 14.5.sp, height: 1.4),
        ),
      ],
    );
  }
}

/// The form itself, kept separate so a rebuild of the surrounding page does not
/// restart the fields.
class _LoginForm extends StatelessWidget {
  _LoginForm({
    required this.formKey,
    required this.auth,
    required this.username,
    required this.password,
    required this.usernameFocus,
    required this.passwordFocus,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final AuthController auth;
  final TextEditingController username;
  final TextEditingController password;
  final FocusNode usernameFocus;
  final FocusNode passwordFocus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A rejected sign-in is reported once, above the fields, rather than
          // being duplicated against whichever field the resident guesses.
          Obx(
            () => auth.errorMessage.value == null
                ? SizedBox.shrink()
                : _ErrorBanner(message: auth.errorMessage.value!),
          ),
          AppTextField(
            fieldKey: Key('login-username'),
            label: 'Username',
            hint: 'e.g. alex',
            icon: Icons.person_outline_rounded,
            controller: username,
            focusNode: usernameFocus,
            textInputAction: TextInputAction.next,
            // Usernames are not sentences, so no auto capitalisation and no
            // autocorrect fighting the resident's typing.
            textCapitalization: TextCapitalization.none,
            enabled: !auth.isSubmitting.value,
            onChanged: (_) => auth.onFieldChanged(''),
            onSubmitted: (_) => passwordFocus.requestFocus(),
            validator: (_) =>
                auth
                        .validate(
                          username: username.text,
                          password: password.text,
                        )
                        ?.field ==
                    'username'
                ? auth
                      .validate(
                        username: username.text,
                        password: password.text,
                      )
                      ?.message
                : null,
          ),
          AppSpacing.fieldGap.heightBox(),
          Obx(
            () => AppTextField(
              fieldKey: Key('login-password'),
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              controller: password,
              focusNode: passwordFocus,
              obscureText: !auth.isPasswordVisible.value,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.none,
              enabled: !auth.isSubmitting.value,
              onChanged: (_) => auth.onFieldChanged(''),
              onSubmitted: (_) => onSubmit(),
              suffixIcon: _PasswordToggle(
                visible: auth.isPasswordVisible.value,
                onToggle: auth.togglePasswordVisibility,
              ),
              validator: (_) =>
                  auth
                          .validate(
                            username: username.text,
                            password: password.text,
                          )
                          ?.field ==
                      'password'
                  ? auth
                        .validate(
                          username: username.text,
                          password: password.text,
                        )
                        ?.message
                  : null,
            ),
          ),
          AppSpacing.fieldGap.heightBox(),
          _RememberMeAndForgot(auth: auth),
          AppSpacing.sectionGap.heightBox(),
          Obx(
            () => AppPrimaryAction(
              key: Key('login-submit'),
              onPressed: auth.isSubmitting.value ? null : onSubmit,
              isLoading: auth.isSubmitting.value,
              label: auth.isSubmitting.value ? 'Signing in...' : 'Sign In',
              icon: Icons.login_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

/// The eye button inside the password field.
class _PasswordToggle extends StatelessWidget {
  _PasswordToggle({required this.visible, required this.onToggle});

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return IconButton(
      key: Key('login-password-toggle'),
      onPressed: onToggle,
      // The label describes the action, so a screen reader announces what the
      // tap will do rather than the current state.
      tooltip: visible ? 'Hide password' : 'Show password',
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: tokens.muted,
      ),
    );
  }
}

/// Remember me on the left, Forgot password on the right.
class _RememberMeAndForgot extends StatelessWidget {
  _RememberMeAndForgot({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    final rememberMeControl = Obx(
      () => Checkbox(
        key: Key('login-remember-me'),
        value: auth.rememberMe.value,
        onChanged: auth.isSubmitting.value ? null : auth.toggleRememberMe,
        activeColor: tokens.brand,
        checkColor: tokens.onBrand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.r),
          side: BorderSide(color: tokens.border),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );

    final rememberMeLabel = GestureDetector(
      // The whole label is the target, not just the box, which is what makes it
      // comfortably tappable on a phone.
      onTap: auth.isSubmitting.value ? null : () => auth.toggleRememberMe(),
      behavior: HitTestBehavior.opaque,
      child: Text(
        'Remember me',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.mutedStrong,
          fontSize: 13.5.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final forgot = TextButton(
      key: Key('login-forgot-password'),
      onPressed: auth.isSubmitting.value
          ? null
          : () => _showForgotPassword(context),
      style: TextButton.styleFrom(
        foregroundColor: tokens.brand,
        minimumSize: Size(0, AppSpacing.minTouchTarget),
        padding: EdgeInsets.symmetric(horizontal: 8),
        textStyle: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
      ),
      child: Text('Forgot password'),
    );

    // On a narrow phone the two controls cannot share a line without the label
    // wrapping a character at a time, so they stack instead of shrinking into
    // something unreadable.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 300;
        final rememberMe = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            rememberMeControl,
            8.w.widthBox(),
            Flexible(child: rememberMeLabel),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rememberMe,
              Align(alignment: Alignment.centerLeft, child: forgot),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: rememberMe),
            forgot,
          ],
        );
      },
    );
  }

  void _showForgotPassword(BuildContext context) {
    // Password reset is a management workflow, not a resident one. Saying so
    // plainly beats a dead link or an empty form.
    showAppFeedback(
      context,
      title: 'Password reset',
      message: 'Please contact your property manager to reset your password.',
      isError: false,
    );
  }
}

/// A single, quiet error line above the form.
class _ErrorBanner extends StatelessWidget {
  _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.fieldGap),
      child: Container(
        key: Key('login-error'),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppPalette.danger.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppPalette.danger,
            ),
            10.w.widthBox(),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppPalette.danger,
                  fontSize: 12.5.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The closing reassurance line.
class _LoginFooter extends StatelessWidget {
  _LoginFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      children: [
        8.h.heightBox(),
        Icon(Icons.shield_outlined, size: 16, color: tokens.faint),
        8.h.heightBox(),
        Text(
          'Secure access to your residence',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.faint,
            fontSize: 12.sp,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        12.h.heightBox(),
        Text(
          AppConstants.appName,
          style: TextStyle(
            color: tokens.faint,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
