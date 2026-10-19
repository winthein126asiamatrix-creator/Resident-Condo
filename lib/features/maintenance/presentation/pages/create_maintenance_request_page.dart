import 'package:test/core/utils/sized_box_extensions.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  CreateMaintenanceRequestPage({this.photoPicker, super.key});

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
  TimeOfDay _preferredTime = TimeOfDay(hour: 10, minute: 0);

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
            key: Key('maintenance-create-scroll'),
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
                _FormSection(
                  title: 'Request details',
                  subtitle: 'The more we know, the faster we can help.',
                  icon: Icons.edit_note_rounded,
                ),
                AppTextField(
                  fieldKey: Key('maintenance-title'),
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
                18.h.heightBox(),
                AppTextField(
                  fieldKey: Key('maintenance-description'),
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
                18.h.heightBox(),
                AppSelectField<MaintenanceCategory>(
                  fieldKey: Key('maintenance-category'),
                  label: 'Category',
                  icon: Icons.category_outlined,
                  value: _category,
                  items: MaintenanceCategory.values,
                  itemBuilder: (category) => category.label,
                  onChanged: (value) => setState(() => _category = value),
                ),
                18.h.heightBox(),
                AppSegmentedControl<MaintenancePriority>(
                  label: 'Priority',
                  segments: {
                    MaintenancePriority.low: 'Low',
                    MaintenancePriority.medium: 'Medium',
                    MaintenancePriority.high: 'High',
                  },
                  icons: {
                    MaintenancePriority.low: Icons.low_priority_rounded,
                    MaintenancePriority.medium: Icons.drag_handle_rounded,
                    MaintenancePriority.high: Icons.priority_high_rounded,
                  },
                  // The colour carries the severity, so it stays per option.
                  colors: {
                    MaintenancePriority.low: AppPalette.success,
                    MaintenancePriority.medium: AppPalette.warning,
                    MaintenancePriority.high: AppPalette.danger,
                  },
                  optionKey: (value) => 'priority-${value.name}',
                  value: _priority,
                  onChanged: (value) => setState(() => _priority = value),
                ),
                24.h.heightBox(),
                _FormSection(
                  title: 'Location & schedule',
                  subtitle: 'Where should our technician go, and when?',
                  icon: Icons.place_outlined,
                ),
                AppTextField(
                  fieldKey: Key('maintenance-location'),
                  label: 'Unit / location',
                  hint: 'Kitchen, master bedroom, lobby...',
                  icon: Icons.home_work_outlined,
                  controller: _locationController,
                  focusNode: _locationFocus,
                  validator: (value) =>
                      AppValidators.requiredText(value, field: 'Location'),
                  textInputAction: TextInputAction.done,
                ),
                18.h.heightBox(),
                _DateTimeRow(
                  date: _preferredDate,
                  time: _preferredTime,
                  onPickDate: _pickDate,
                  onPickTime: _pickTime,
                ),
                24.h.heightBox(),
                _FormSection(
                  title: 'Photos',
                  subtitle: 'Photos are optional and help us diagnose faster.',
                  icon: Icons.photo_camera_outlined,
                ),
                if (_photos.isNotEmpty) ...[
                  14.h.heightBox(),
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
                  10.h.heightBox(),
                  Text(
                    _photos.length == 1
                        ? '1 photo attached'
                        : '${_photos.length} photos attached',
                    key: Key('maintenance-photo-count'),
                    style: TextStyle(
                      color: AppThemeTokens.of(context).muted,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_photos.isNotEmpty) 12.h.heightBox(),
                _AttachPhotoButton(onPressed: _attachPhoto),
                28.h.heightBox(),
                if (controller.errorMessage.value != null) ...[
                  _ErrorBanner(message: controller.errorMessage.value!),
                  14.h.heightBox(),
                ],
                AppPrimaryAction(
                  key: Key('submit-maintenance-request'),
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
    final picker = widget.photoPicker ?? DevicePhotoPicker();
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            10.h.heightBox(),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            6.h.heightBox(),
            ListTile(
              key: Key('photo-source-gallery'),
              leading: Icon(Icons.photo_library_outlined, color: tokens.brand),
              title: Text(
                'Choose from gallery',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pick an existing photo',
                style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              key: Key('photo-source-camera'),
              leading: Icon(Icons.photo_camera_outlined, color: tokens.brand),
              title: Text(
                'Take a photo',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Use the device camera',
                style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
              ),
              onTap: () {
                Navigator.pop(sheetContext, ImageSource.camera);
              },
            ),
            8.h.heightBox(),
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
  _FormSection({
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
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 17, color: tokens.brand),
            ),
            10.w.widthBox(),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        4.h.heightBox(),
        Padding(
          padding: EdgeInsets.only(left: 40),
          child: Text(
            subtitle,
            style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
          ),
        ),
      ],
    );
  }
}

/// A picked photo shown as a thumbnail, with a remove affordance in the corner
/// so the resident can drop a photo they attached by mistake.
class _PhotoThumbnail extends StatelessWidget {
  _PhotoThumbnail({
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
              borderRadius: BorderRadius.circular(16.r),
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
              shape: CircleBorder(),
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
  _DateTimeRow({
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
            key: Key('maintenance-date'),
            label: null,
            icon: Icons.calendar_today_outlined,
            value: AppDates.format(date),
            onPressed: onPickDate,
          ),
        ),
        10.w.widthBox(),
        Expanded(
          flex: 2,
          child: AppPickerField(
            key: Key('maintenance-time'),
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
  _AttachPhotoButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
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
              Icon(Icons.add_a_photo_outlined, size: 18, color: tokens.brand),
              9.w.widthBox(),
              Text(
                'Attach photo',
                style: TextStyle(
                  color: tokens.brand,
                  fontSize: 14.sp,
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
  _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('maintenance-submit-error'),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: AppPalette.danger),
          8.w.widthBox(),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppPalette.danger,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
