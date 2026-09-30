import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';

class CreateMaintenanceRequestPage extends StatefulWidget {
  const CreateMaintenanceRequestPage({super.key});

  @override
  State<CreateMaintenanceRequestPage> createState() =>
      _CreateMaintenanceRequestPageState();
}

class _CreateMaintenanceRequestPageState
    extends State<CreateMaintenanceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _photoLabels = <String>[];
  MaintenanceCategory _category = MaintenanceCategory.plumbing;
  MaintenancePriority _priority = MaintenancePriority.medium;
  DateTime _preferredDate = DateTime(2026, 9, 30);
  TimeOfDay _preferredTime = const TimeOfDay(hour: 10, minute: 0);

  MaintenanceController get controller => Get.find<MaintenanceController>();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Obx(
          () => SingleChildScrollView(
            key: const Key('maintenance-create-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            // A single scroll view keeps every field alive, so validation
            // errors survive scrolling and the submit CTA is always reachable.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormSection(
                  title: 'Request details',
                  subtitle: 'The more we know, the faster we can help.',
                  icon: Icons.edit_note_rounded,
                ),
                AppTextField(
                  fieldKey: const Key('maintenance-title'),
                  label: 'Issue title',
                  hint: 'Describe the issue',
                  icon: Icons.title_rounded,
                  controller: _titleController,
                  focusNode: _titleFocus,
                  validator: (value) =>
                      AppValidators.requiredText(value, field: 'Title'),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _descriptionFocus.requestFocus(),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  fieldKey: const Key('maintenance-description'),
                  label: 'Description',
                  hint: 'Tell us what happened...',
                  icon: Icons.notes_rounded,
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  maxLines: 5,
                  minLines: 4,
                  validator: (value) =>
                      AppValidators.requiredText(value, field: 'Description'),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _locationFocus.requestFocus(),
                ),
                const SizedBox(height: 18),
                AppSelectField<MaintenanceCategory>(
                  fieldKey: const Key('maintenance-category'),
                  label: 'Category',
                  icon: Icons.category_outlined,
                  value: _category,
                  items: MaintenanceCategory.values,
                  itemBuilder: (category) => category.label,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 18),
                _PriorityPicker(
                  value: _priority,
                  onChanged: (value) => setState(() => _priority = value),
                ),
                const SizedBox(height: 24),
                const _FormSection(
                  title: 'Location & schedule',
                  subtitle: 'Where should our technician go, and when?',
                  icon: Icons.place_outlined,
                ),
                AppTextField(
                  fieldKey: const Key('maintenance-location'),
                  label: 'Unit / location',
                  hint: 'Kitchen, master bedroom, lobby...',
                  icon: Icons.home_work_outlined,
                  controller: _locationController,
                  focusNode: _locationFocus,
                  validator: (value) =>
                      AppValidators.requiredText(value, field: 'Location'),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                _DateTimeRow(
                  date: _preferredDate,
                  time: _preferredTime,
                  onPickDate: _pickDate,
                  onPickTime: _pickTime,
                ),
                const SizedBox(height: 24),
                const _FormSection(
                  title: 'Photos',
                  subtitle: 'Photos are optional and help us diagnose faster.',
                  icon: Icons.photo_camera_outlined,
                ),
                if (_photoLabels.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _photoLabels
                        .map(
                          (label) => Chip(
                            avatar: const Icon(Icons.photo_outlined, size: 17),
                            label: Text(label),
                            backgroundColor: AppPalette.brandTint,
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: AppPalette.brand,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                if (_photoLabels.isNotEmpty) const SizedBox(height: 12),
                _AttachPhotoButton(onPressed: _addMockPhoto),
                const SizedBox(height: 28),
                if (controller.errorMessage.value != null) ...[
                  _ErrorBanner(message: controller.errorMessage.value!),
                  const SizedBox(height: 14),
                ],
                AppPrimaryAction(
                  key: const Key('submit-maintenance-request'),
                  onPressed: controller.isSubmitting.value ? null : _submit,
                  isLoading: controller.isSubmitting.value,
                  label: 'Submit Request',
                  icon: Icons.send_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Custom app bar: safe area aware, hairline separated and carrying a short
  /// helper line instead of the default Material toolbar.
  PreferredSizeWidget _buildAppBar() {
    final topInset = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(70 + topInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppPalette.surface,
          border: Border(bottom: BorderSide(color: AppPalette.border)),
        ),
        padding: EdgeInsets.fromLTRB(16, topInset, 20, 14),
        child: Row(
          children: [
            const _BackButton(),
            const SizedBox(width: 12),
            // Single lines with ellipsis so a narrow phone or a large text
            // scale can never push the toolbar out of its bounds.
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Request',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 18,
                      height: 1.2,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tell us what needs attention',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    if (selected != null) setState(() => _preferredDate = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _preferredTime,
    );
    if (selected != null) setState(() => _preferredTime = selected);
  }

  void _addMockPhoto() {
    setState(
      () => _photoLabels.add('Photo ${_photoLabels.length + 1} attached'),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final request = await controller.createRequest(
      title: _titleController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      priority: _priority,
      preferredDate: AppDates.format(_preferredDate),
      preferredTime: _preferredTime.format(context),
      photoNames: _photoLabels,
    );
    if (request != null && mounted) {
      Get.back(result: request);
      Get.snackbar(
        'Request submitted',
        '${request.title} is now with the maintenance team.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

/// Titled group header that keeps the form scannable on a phone.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppPalette.brandTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: AppPalette.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: 'Back',
        child: InkWell(
          onTap: () => Get.back<void>(),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Three way priority choice: a segmented control is far easier to hit on a
/// phone than a dropdown, and it keeps the value visible at all times.
class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final MaintenancePriority value;
  final ValueChanged<MaintenancePriority> onChanged;

  static const _options = <MaintenancePriority, (IconData, Color, String)>{
    MaintenancePriority.low: (
      Icons.low_priority_rounded,
      AppPalette.success,
      'Low',
    ),
    MaintenancePriority.medium: (
      Icons.drag_handle_rounded,
      AppPalette.warning,
      'Medium',
    ),
    MaintenancePriority.high: (
      Icons.priority_high_rounded,
      AppPalette.danger,
      'High',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            color: AppPalette.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final entry in _options.entries) ...[
              Expanded(
                child: _PriorityOption(
                  key: ValueKey('priority-${entry.key.name}'),
                  label: entry.value.$3,
                  icon: entry.value.$1,
                  color: entry.value.$2,
                  selected: entry.key == value,
                  onTap: () => onChanged(entry.key),
                ),
              ),
              if (entry.key != _options.keys.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? color : AppPalette.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? color : AppPalette.muted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : AppPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _PickerButton(
            key: const Key('maintenance-date'),
            icon: Icons.calendar_today_outlined,
            label: AppDates.format(date),
            onPressed: onPickDate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _PickerButton(
            key: const Key('maintenance-time'),
            icon: Icons.schedule_outlined,
            label: time.format(context),
            onPressed: onPickTime,
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppPalette.muted),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachPhotoButton extends StatelessWidget {
  const _AttachPhotoButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 18,
                color: AppPalette.brand,
              ),
              SizedBox(width: 9),
              Text(
                'Attach photo',
                style: TextStyle(
                  color: AppPalette.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('maintenance-submit-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppPalette.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppPalette.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
