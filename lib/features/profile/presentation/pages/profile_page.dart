import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/localization/app_locale_controller.dart';

import '../../../../core/theme/app_radius.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_form_field.dart';

import '../../../../core/widgets/app_primary_action.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

import '../../../dashboard/presentation/controllers/dashboard_controller.dart';

import '../../../session/presentation/controllers/session_controller.dart';

import '../../domain/entities/profile.dart';

import '../controllers/profile_controller.dart';

import '../widgets/language_picker_sheet.dart';

/// The greeting line at the top of the profile page.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                  letterSpacing: -0.4,
                ),
              ),
              4.h.heightBox(),
              Text(
                'Manage your resident details and preferences',
                style: TextStyle(color: tokens.muted, fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = Get.find<AppLocaleController>();
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
              key: const Key('profile-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.pageTop,
                AppSpacing.gutter,
                AppSpacing.pageBottom,
              ),
              children: [
                _PageHeader(profile: profile),
                AppSpacing.sectionGap.heightBox(),
                _ProfileHero(
                  profile: profile,
                  onEdit: () => _editProfile(context, profile),
                ),
                AppSpacing.sectionGap.heightBox(),
                _SectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Personal information',
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full name',
                      value: profile.name,
                    ),
                    const _RowDivider(),
                    _InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: profile.email,
                    ),
                    const _RowDivider(),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: profile.phone,
                    ),
                    const _RowDivider(),
                    _InfoRow(
                      icon: Icons.apartment_rounded,
                      label: 'Unit',
                      value: profile.unit,
                    ),
                  ],
                ),
                AppSpacing.sectionGap.heightBox(),
                _SectionCard(
                  icon: Icons.tune_rounded,
                  title: 'Preferences',
                  children: [
                    _PreferenceRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notification preferences',
                      value: profile.notificationsEnabled
                          ? 'Enabled'
                          : 'Disabled',
                      onTap: () => controller.toggleNotifications(
                        !profile.notificationsEnabled,
                      ),
                      trailing: Switch.adaptive(
                        value: profile.notificationsEnabled,
                        onChanged: controller.toggleNotifications,
                      ),
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.palette_outlined,
                      label: 'App appearance',
                      onTap: () => Get.toNamed(AppRoutes.appearance),
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.translate_rounded,
                      label: 'Language',
                      value: localeController.displayName(
                        localeController.locale.languageCode,
                      ),
                      onTap: () {
                        vibrateNow();
                        _chooseLanguage(context, profile);
                      },
                    ),
                  ],
                ),
                AppSpacing.sectionGap.heightBox(),
                _SectionCard(
                  icon: Icons.grid_view_rounded,
                  title: 'Resident services',
                  children: [
                    _ActionRow(
                      icon: Icons.grid_view_rounded,
                      label: 'All resident services',
                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.more);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.description_outlined,
                      label: 'Rental & lease',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.lease);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.people_alt_outlined,
                      label: 'Visitors',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.visitors);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.room_service_outlined,
                      label: 'Condo services',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.services);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.storefront_outlined,
                      label: 'Convenience Store',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.store);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Parking',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.parking);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.support_agent_outlined,
                      label: 'Complaints',
                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.complaints);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.gavel_outlined,
                      label: 'Rules & violations',

                      onTap: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.rules);
                      },
                    ),
                  ],
                ),
                AppSpacing.sectionGap.heightBox(),
                _SectionCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Account',
                  children: [
                    _ActionRow(
                      icon: Icons.edit_outlined,
                      label: 'Edit profile',
                      onTap: () {
                        vibrateNow();
                        _editProfile(context, profile);
                      },
                    ),
                    const _RowDivider(),
                    _ActionRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change password',
                      onTap: () {
                        vibrateNow();
                        _changePassword(context);
                      },
                    ),
                    const _RowDivider(),
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
                    const _RowDivider(),
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
                AppSpacing.sectionGap.heightBox(),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC2410C),
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0xFFF0C6C0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
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
    final localeController = Get.find<AppLocaleController>();
    final chosen = await showLanguagePickerSheet(
      context,
      localeController: localeController,
    );
    if (chosen == null || chosen == localeController.locale.languageCode) {
      return;
    }
    await localeController.setLanguageCode(chosen);
    await controller.updateProfile(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      language: localeController.englishName(chosen),
    );
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
          14.h.heightBox(),
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
        content: Text('You will be signed out and asked to sign in again.'),
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
  const _ProfileHero({required this.profile, required this.onEdit});

  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.brand, tokens.brandDark],
        ),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.brandOnDark.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 31,
                  backgroundColor: tokens.brandOnDark,
                  child: Text(
                    profile.initials,
                    style: TextStyle(
                      color: tokens.brandDark,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              15.w.widthBox(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.brandOnDark,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    6.h.heightBox(),
                    _UnitBadge(unit: profile.unit),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The unit number rendered as a translucent pill on the hero panel.
class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: tokens.brandOnDark.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tokens.brandOnDark.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 13,
            color: tokens.brandOnDarkMuted,
          ),
          5.w.widthBox(),
          Flexible(
            child: Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.brandOnDark,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.icon});

  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tokens.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 17, color: tokens.brand),
                ),
                10.w.widthBox(),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.sp,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.cardGap.heightBox(),
          ...children,
        ],
      ),
    );
  }
}

/// A hairline between the rows of a card, inset so it starts after the icon.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 34),
      child: Divider(height: 1, thickness: 1, color: tokens.border),
    );
  }
}

/// The rounded square icon that leads a row.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Icon(icon, size: 15, color: tokens.brand),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          12.w.widthBox(),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 13.sp),
            ),
          ),
          10.w.widthBox(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                    color: tokens.ink,
                  ),
                ),
                3.h.heightBox(),
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

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: content,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _RowIcon(icon: icon),
              12.w.widthBox(),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                    color: tokens.ink,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
              4.w.widthBox(),
              Icon(Icons.chevron_right_rounded, color: tokens.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});
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
            20.h.heightBox(),
            Text(
              'Edit profile',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20.sp),
            ),
            15.h.heightBox(),
            AppTextField(
              fieldKey: Key('profile-name-field'),
              label: 'Full name',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
            ),
            AppSpacing.fieldGap.heightBox(),
            AppTextField(
              fieldKey: Key('profile-email-field'),
              label: 'Email',
              controller: _emailController,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            AppSpacing.fieldGap.heightBox(),
            AppTextField(
              fieldKey: Key('profile-phone-field'),
              label: 'Phone',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            20.h.heightBox(),
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
