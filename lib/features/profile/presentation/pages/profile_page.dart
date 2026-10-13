import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:test/features/dashboard/presentation/controllers/dashboard_controller.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/resident_role.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/profile.dart';
import '../controllers/profile_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_primary_action.dart';

class ProfilePage extends GetView<ProfileController> {
  ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.profile.value == null) {
            return Center(child: CircularProgressIndicator());
          }
          if (controller.errorMessage.value != null &&
              controller.profile.value == null) {
            return AppStateMessage(
              title: 'Unable to load profile',
              message: controller.errorMessage.value!,
              icon: Icons.person_outline_rounded,
              actionLabel: 'Try again',
              onAction: controller.loadProfile,
            );
          }
          final profile = controller.profile.value;
          if (profile == null) {
            return AppStateMessage(
              title: 'No profile information',
              message: 'Your resident profile is not available right now.',
              icon: Icons.person_outline_rounded,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadProfile,
            child: ListView(
              key: Key('profile-scroll'),
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                SizedBox(height: 18.h),
                _ProfileHero(profile: profile),
                SizedBox(height: 22.h),
                // _SectionCard(
                //   title: 'Role-based view',
                //   subtitle: 'Demo switch: the app adapts to each role.',
                //   children: [
                //     _RoleSelector(
                //       selected: role,
                //       onChanged: (next) => _applyRole(next),
                //     ),
                //   ],
                // ),
                // SizedBox(height: 14.h),
                _SectionCard(
                  title: 'Personal information',
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full name',
                      value: profile.name,
                    ),
                    _InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: profile.email,
                    ),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: profile.phone,
                    ),
                    _InfoRow(
                      icon: Icons.apartment_rounded,
                      label: 'Unit',
                      value: profile.unit,
                    ),
                    // _InfoRow(
                    //   icon: Icons.badge_outlined,
                    //   label: 'Role',
                    //   value: profile.role,
                    // ),
                  ],
                ),
                SizedBox(height: 14.h),
                _SectionCard(
                  title: 'Preferences',
                  children: [
                    _PreferenceRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notification preferences',
                      value: profile.notificationsEnabled
                          ? 'Enabled'
                          : 'Disabled',
                      trailing: Switch.adaptive(
                        value: profile.notificationsEnabled,
                        onChanged: controller.toggleNotifications,
                      ),
                    ),
                    _ActionRow(
                      icon: Icons.palette_outlined,
                      label: 'App appearance',
                      onTap: () => Get.toNamed(AppRoutes.appearance),
                    ),
                    _ActionRow(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: profile.language,
                      onTap: () => _chooseLanguage(context, profile),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _SectionCard(
                  title: 'Resident services',
                  children: [
                    _ActionRow(
                      icon: Icons.grid_view_rounded,
                      label: 'All resident services',
                      onTap: () => Get.toNamed(AppRoutes.more),
                    ),
                    _ActionRow(
                      icon: Icons.description_outlined,
                      label: 'Rental & lease',
                      onTap: () => Get.toNamed(AppRoutes.lease),
                    ),
                    _ActionRow(
                      icon: Icons.people_alt_outlined,
                      label: 'Visitors',
                      onTap: () => Get.toNamed(AppRoutes.visitors),
                    ),
                    _ActionRow(
                      icon: Icons.room_service_outlined,
                      label: 'Condo services',
                      onTap: () => Get.toNamed(AppRoutes.services),
                    ),
                    _ActionRow(
                      icon: Icons.storefront_outlined,
                      label: 'Convenience Store',
                      onTap: () => Get.toNamed(AppRoutes.store),
                    ),
                    _ActionRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Parking',
                      onTap: () => Get.toNamed(AppRoutes.parking),
                    ),
                    _ActionRow(
                      icon: Icons.support_agent_outlined,
                      label: 'Complaints',
                      onTap: () => Get.toNamed(AppRoutes.complaints),
                    ),
                    _ActionRow(
                      icon: Icons.gavel_outlined,
                      label: 'Rules & violations',
                      onTap: () => Get.toNamed(AppRoutes.rules),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _SectionCard(
                  title: 'Account',
                  children: [
                    // _ActionRow(
                    //   icon: Icons.badge_outlined,
                    //   label: 'Account type',
                    //   value: role.label,
                    //   onTap: () => _switchRole(context, role),
                    // ),
                    _ActionRow(
                      icon: Icons.edit_outlined,
                      label: 'Edit profile',
                      onTap: () => _editProfile(context, profile),
                    ),
                    _ActionRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change password',
                      onTap: () => _changePassword(context),
                    ),
                    _ActionRow(
                      icon: Icons.credit_card_outlined,
                      label: 'Payment methods',
                      value: '•••• 4821',
                      onTap: () => _showMessage(
                        context,
                        'Payment methods',
                        'Payment method management will be available soon.',
                      ),
                    ),
                    _ActionRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & support',
                      onTap: () => _showMessage(
                        context,
                        'Help & support',
                        'Our resident support team is here to help.',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: Icon(Icons.logout_rounded, size: 18),
                  label: Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFC2410C),
                    minimumSize: Size.fromHeight(50),
                    side: BorderSide(color: Color(0xFFF0C6C0)),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, Profile profile) async {
    final result =
        await showModalBottomSheet<({String name, String email, String phone})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: false,
          builder: (_) => _EditProfileSheet(profile: profile),
        );
    if (result == null) {
      return;
    }
    final updated = await controller.updateProfile(
      name: result.name,
      email: result.email,
      phone: result.phone,
    );
    if (updated != null && context.mounted) {
      _showMessage(
        context,
        'Profile updated',
        'Your personal information has been saved locally.',
      );
    }
  }

  Future<void> _chooseLanguage(BuildContext context, Profile profile) async {
    final tokens = AppThemeTokens.of(context);
    final language = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: false,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Language',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20.sp),
              ),
              SizedBox(height: 10.h),
              for (final option in ['English', 'Myanmar', 'Chinese'])
                ListTile(
                  title: Text(option),
                  trailing: option == profile.language
                      ? Icon(Icons.check_rounded, color: tokens.brand)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (language == null) return;
    final updated = await controller.updateProfile(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      language: language,
    );
    if (updated != null && context.mounted) {
      _showMessage(
        context,
        'Language updated',
        'Your language preference has been saved locally.',
      );
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final confirmed = await showAppFormDialog(
      context,
      title: 'Change password',
      message: 'Use at least 8 characters with a number and a letter.',
      icon: Icons.lock_outline_rounded,
      confirmLabel: 'Save',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Current password',
            obscureText: true,
            icon: Icons.lock_outline_rounded,
          ),
          SizedBox(height: 14.h),
          AppTextField(
            label: 'New password',
            obscureText: true,
            icon: Icons.lock_reset_rounded,
          ),
        ],
      ),
    );
    if (confirmed && context.mounted) {
      _showMessage(
        context,
        'Password updated',
        'Your password was changed in this local demo.',
      );
    }
  }

  void _showMessage(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$title: $message')));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout?'),
        content: Text(
          'You will be signed out and asked to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) {
      return;
    }
    // Clears the stored tokens and the remembered details first, so the splash
    // will not quietly sign the resident back in on the next launch and no
    // later request can reuse the old credentials.
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().signOut();
    }
    // Drops the in-memory resident too, so the next person to sign in on this
    // device does not briefly see the previous one's name and email.
    if (Get.isRegistered<SessionController>()) {
      Get.find<SessionController>().clearResident();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().selectedTab.value = 0;
    }
    Get.offAllNamed(AppRoutes.login);
  }
}

class _ProfileHero extends StatelessWidget {
  _ProfileHero({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F766E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: tokens.brandSoft,
            child: Text(
              profile.initials,
              style: TextStyle(
                color: tokens.brand,
                fontSize: 21.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  profile.unit,
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Change profile photo',
            icon: Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: TextStyle(color: tokens.muted, fontSize: 11.sp),
            ),
          ],
          SizedBox(height: 5.h),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.brand),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
  });
  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.brand),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  value,
                  style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  _ActionRow({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.brand),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp),
              ),
            ),
            if (value != null)
              Text(value!, style: TextStyle(color: tokens.muted, fontSize: 11.sp)),
            SizedBox(width: 5.w),
            Icon(Icons.chevron_right_rounded, color: tokens.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  _EditProfileSheet({required this.profile});
  final Profile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(text: widget.profile.phone);
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
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
            SizedBox(height: 20.h),
            Text(
              'Edit profile',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20.sp),
            ),
            SizedBox(height: 15.h),
            AppTextField(
              fieldKey: Key('profile-name-field'),
              label: 'Full name',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
            ),
            SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              fieldKey: Key('profile-email-field'),
              label: 'Email',
              controller: _emailController,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              fieldKey: Key('profile-phone-field'),
              label: 'Phone',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20.h),
            AppPrimaryAction(
              key: Key('profile-save'),
              onPressed: _save,
              label: 'Save changes',
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    Navigator.pop(context, (
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    ));
  }
}
