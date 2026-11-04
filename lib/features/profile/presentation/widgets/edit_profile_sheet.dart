import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../auth/data/models/auth_user.dart';
import '../controllers/profile_controller.dart';

/// Edits the three profile fields the backend accepts on `PATCH /me`.
///
/// The sheet owns only its transient form state. Saving is delegated to
/// [onSubmit], which returns null on success or a localized error message on
/// failure. A failure leaves the sheet open so the resident's values are not
/// lost, and only a successful save closes it.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    required this.user,
    required this.onSubmit,
    super.key,
  });

  final AuthUser user;
  final Future<String?> Function(String name, String email, String phone)
  onSubmit;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isSaving = false;
  bool _showFieldErrors = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _phoneController = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final autovalidateMode = _showFieldErrors
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return PopScope(
      canPop: !_isSaving,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: autovalidateMode,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  20.h.heightBox(),
                  Text(
                    'editProfile'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20.sp,
                      color: tokens.ink,
                    ),
                  ),
                  15.h.heightBox(),
                  AppTextField(
                    fieldKey: const Key('profile-name-field'),
                    label: 'fullName'.tr,
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    enabled: !_isSaving,
                    validator: ProfileController.validateProfileName,
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  AppTextField(
                    fieldKey: const Key('profile-email-field'),
                    label: 'email'.tr,
                    controller: _emailController,
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isSaving,
                    validator: ProfileController.validateProfileEmail,
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  AppTextField(
                    fieldKey: const Key('profile-phone-field'),
                    label: 'phone'.tr,
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !_isSaving,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                    ],
                    validator: ProfileController.validateProfilePhone,
                    onSubmitted: (_) => _save(),
                  ),
                  if (_error != null && _error!.isNotEmpty) ...[
                    14.h.heightBox(),
                    Container(
                      key: const Key('profile-edit-error'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppPalette.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 17,
                            color: AppPalette.danger,
                          ),
                          8.w.widthBox(),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppPalette.danger,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  20.h.heightBox(),
                  AppPrimaryAction(
                    key: const Key('profile-save'),
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    label: _isSaving ? 'savingChanges'.tr : 'saveChanges'.tr,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _showFieldErrors = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    String? failure;
    try {
      failure = await widget.onSubmit(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
      );
    } catch (_) {
      failure = 'profileUpdateFailed'.tr;
    }
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _error = failure;
    });
  }
}
