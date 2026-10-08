import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/photo_picker.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_picker_field.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';
import '../../../../core/widgets/app_segmented_control.dart';

class CreateMaintenanceRequestPage extends StatefulWidget {
  const CreateMaintenanceRequestPage({this.photoPicker, super.key});

  /// Overridden in tests; the app uses the device gallery and camera.
  final PhotoPicker? photoPicker;

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
  final _photos = <AttachedPhoto>[];
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
      resizeToAvoidBottomInset: true,
      appBar: AppDetailAppBar(
        title: 'New Request',
        subtitle: 'Tell us what needs attention',
        onBack: () => Get.back<void>(),
      ),
      body: Form(
        key: _formKey,
        child: Obx(
          () => SingleChildScrollView(
            key: const Key('maintenance-create-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
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
                AppSegmentedControl<MaintenancePriority>(
                  label: 'Priority',
                  segments: const {
                    MaintenancePriority.low: 'Low',
                    MaintenancePriority.medium: 'Medium',
                    MaintenancePriority.high: 'High',
                  },
                  icons: const {
                    MaintenancePriority.low: Icons.low_priority_rounded,
                    MaintenancePriority.medium: Icons.drag_handle_rounded,
                    MaintenancePriority.high: Icons.priority_high_rounded,
                  },
                  // The colour carries the severity, so it stays per option.
                  colors: const {
                    MaintenancePriority.low: AppPalette.success,
                    MaintenancePriority.medium: AppPalette.warning,
                    MaintenancePriority.high: AppPalette.danger,
                  },
                  optionKey: (value) => 'priority-${value.name}',
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
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var index = 0; index < _photos.length; index++)
                        _PhotoThumbnail(
                          key: Key('maintenance-photo-$index'),
                          photo: _photos[index],
                          position: index + 1,
                          onRemove: () => _removePhoto(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _photos.length == 1
                        ? '1 photo attached'
                        : '${_photos.length} photos attached',
                    key: const Key('maintenance-photo-count'),
                    style: TextStyle(
                      color: AppThemeTokens.of(context).muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_photos.isNotEmpty) const SizedBox(height: 12),
                _AttachPhotoButton(onPressed: _attachPhoto),
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

  /// Asks where the photo should come from, then hands the pick to the platform
  /// picker. Cancelling either step leaves the form untouched.
  Future<void> _attachPhoto() async {
    final source = await _choosePhotoSource();
    if (source == null || !mounted) {
      return;
    }
    final picker = widget.photoPicker ?? const DevicePhotoPicker();
    final result = await picker.pick(source);
    if (!mounted) {
      return;
    }
    final photo = result.photo;
    if (photo != null) {
      setState(() => _photos.add(photo));
      return;
    }
    final error = result.error;
    if (error != null) {
      showAppFeedback(
        context,
        title: 'Could not attach photo',
        message: error,
        isError: true,
      );
    }
  }

  Future<ImageSource?> _choosePhotoSource() {
    final tokens = AppThemeTokens.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              key: const Key('photo-source-gallery'),
              leading: Icon(
                Icons.photo_library_outlined,
                color: tokens.brand,
              ),
              title: Text(
                'Choose from gallery',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pick an existing photo',
                style: TextStyle(color: tokens.muted, fontSize: 12.5),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('photo-source-camera'),
              leading: Icon(
                Icons.photo_camera_outlined,
                color: tokens.brand,
              ),
              title: Text(
                'Take a photo',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Use the device camera',
                style: TextStyle(color: tokens.muted, fontSize: 12.5),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
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
      // The request carries the file names and where each photo lives, so the
      // details screen can show the very image that was picked. The repository
      // does not upload the images themselves yet.
      photoNames: _photos.map((photo) => photo.name).toList(),
      photoPaths: _photos.map((photo) => photo.path).toList(),
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
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.brandTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: tokens.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: tokens.ink,
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
            style: TextStyle(color: tokens.muted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// A picked photo shown as a thumbnail, with a remove affordance in the corner
/// so the resident can drop a photo they attached by mistake.
class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.position,
    required this.onRemove,
    super.key,
  });

  final AttachedPhoto photo;

  /// 1 based position, used for the remove button's tooltip and semantics.
  final int position;
  final VoidCallback onRemove;

  static const _size = 76.0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              // A file that is gone or unsupported must not break the form.
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 22,
                  color: tokens.faint,
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: tokens.ink,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Tooltip(
                message: 'Remove photo $position',
                child: InkWell(
                  key: Key('maintenance-photo-remove-$position'),
                  onTap: onRemove,
                  child: Semantics(
                    button: true,
                    label: 'Remove photo $position',
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        // The remove badge sits on the ink fill, which inverts
                        // with the theme, so the glyph is picked from it.
                        color: AppThemeTokens.onColor(tokens.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three way priority choice: a segmented control is far easier to hit on a
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
          child: AppPickerField(
            key: const Key('maintenance-date'),
            label: null,
            icon: Icons.calendar_today_outlined,
            value: AppDates.format(date),
            onPressed: onPickDate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppPickerField(
            key: const Key('maintenance-time'),
            label: null,
            icon: Icons.schedule_outlined,
            value: time.format(context),
            onPressed: onPickTime,
          ),
        ),
      ],
    );
  }
}

class _AttachPhotoButton extends StatelessWidget {
  const _AttachPhotoButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 18,
                color: tokens.brand,
              ),
              const SizedBox(width: 9),
              Text(
                'Attach photo',
                style: TextStyle(
                  color: tokens.brand,
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
