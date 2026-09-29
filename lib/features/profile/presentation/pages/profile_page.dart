import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/resident_role.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/profile.dart';
import '../controllers/profile_controller.dart';

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  ResidentRole get _role => Get.isRegistered<SessionController>()
      ? Get.find<SessionController>().session.value.role
      : ResidentRole.owner;

  /// Switching role also swaps the payment ledger so the tenant sees their own
  /// Monthly Rent line next to the condo fee.
  Future<void> _applyRole(ResidentRole next) async {
    final session = Get.find<SessionController>();
    if (session.role == next) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      Get.context!,
      title: 'Switch to ${next.label}?',
      message:
          'The app will show the screens and charges for a ${next.label.toLowerCase()} '
          'account. ${next.description}',
      confirmLabel: 'Switch role',
    );
    if (!confirmed) {
      return;
    }
    session.switchRole(next);
    if (Get.isRegistered<PaymentController>()) {
      await Get.find<PaymentController>().applyRole(next.name);
    }
    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().syncRole(next);
    }
  }

  Future<void> _switchRole(BuildContext context, ResidentRole current) async {
    for (final option in ResidentRole.values) {
      if (option == current) {
        continue;
      }
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'Switch to ${option.label}?',
        message: option.description,
        confirmLabel: 'Switch',
      );
      if (confirmed) {
        await _applyRole(option);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.profile.value == null) {
            return const Center(child: CircularProgressIndicator());
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
          if (controller.isLoggedOut.value) {
            return AppStateMessage(
              title: 'You are signed out',
              message: 'Your session has ended in this local demo.',
              icon: Icons.logout_rounded,
              actionLabel: 'Sign back in',
              onAction: controller.restoreSession,
            );
          }
          final profile = controller.profile.value;
          if (profile == null) {
            return const AppStateMessage(
              title: 'No profile information',
              message: 'Your resident profile is not available right now.',
              icon: Icons.person_outline_rounded,
            );
          }
          final role = _role;

          return RefreshIndicator(
            onRefresh: controller.loadProfile,
            child: ListView(
              key: const Key('profile-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2B2A),
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileHero(profile: profile),
                const SizedBox(height: 22),
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
                // const SizedBox(height: 14),
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
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Role',
                      value: profile.role,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: profile.language,
                      onTap: () => _chooseLanguage(context, profile),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Account',
                  children: [
                    _ActionRow(
                      icon: Icons.badge_outlined,
                      label: 'Account type',
                      value: role.label,
                      onTap: () => _switchRole(context, role),
                    ),
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
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC2410C),
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFF0C6C0)),
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
    final language = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: false,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Language',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 10),
              for (final option in ['English', 'Spanish', 'French'])
                ListTile(
                  title: Text(option),
                  trailing: option == profile.language
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF0F766E),
                        )
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

  void _changePassword(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Current password'),
            ),
            SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage(
                context,
                'Password updated',
                'Your password was changed in this local demo.',
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$title: $message')));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be signed out of this local demo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      controller.logout();
    }
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});
  final ResidentRole selected;
  final ValueChanged<ResidentRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in ResidentRole.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              key: Key('role-option-${role.name}'),
              onTap: () => onChanged(role),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: role == selected ? AppPalette.brandTint : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: role == selected
                        ? AppPalette.brand
                        : AppPalette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      role == selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: role == selected
                          ? AppPalette.brand
                          : AppPalette.faint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role.description,
                            style: const TextStyle(
                              color: AppPalette.muted,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
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
            backgroundColor: const Color(0xFFBFE8DF),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Color(0xFF0F766E),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${profile.role} · ${profile.unit}',
                  style: const TextStyle(
                    color: Color(0xFFD8F3EC),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Change profile photo',
            icon: const Icon(
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
  const _SectionCard({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EEEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF71807D), fontSize: 11),
            ),
          ],
          const SizedBox(height: 5),
          ...children,
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF71807D), fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
  });
  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF71807D),
                    fontSize: 11,
                  ),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0F766E)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(color: Color(0xFF71807D), fontSize: 11),
              ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA9A5),
              size: 20,
            ),
          ],
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
                  color: const Color(0xFFD5E2DE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit profile',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save changes'),
              ),
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
