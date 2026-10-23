import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../domain/entities/complaint.dart';

import '../controllers/complaint_controller.dart';

import '../widgets/complaint_widgets.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_form_field.dart';

import '../../../../core/widgets/app_segmented_control.dart';

import '../../../../core/theme/app_spacing.dart';

class CreateComplaintPage extends StatefulWidget {
  const CreateComplaintPage({super.key});

  @override
  State<CreateComplaintPage> createState() => _CreateComplaintPageState();
}

class _CreateComplaintPageState extends State<CreateComplaintPage> {
  final ComplaintController controller = Get.find<ComplaintController>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  ComplaintCategory _category = ComplaintCategory.noise;
  ComplaintPriority _priority = ComplaintPriority.medium;
  bool _isAnonymous = false;
  String _error = '';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'File a complaint'),
      body: Obx(
        () => ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.pageBottom,
          ),
          children: [
            Text(
              'What happened?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            AppSpacing.fieldLabelGap.heightBox(),
            AppTextField(
              label: 'Subject',
              fieldKey: Key('complaint-subject-field'),
              controller: _subjectController,
              hint: 'Short summary of the issue',
            ),
            AppSpacing.fieldGap.heightBox(),
            Text(
              'Details',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            AppSpacing.fieldLabelGap.heightBox(),
            AppTextField(
              label: 'Description',
              fieldKey: Key('complaint-description-field'),
              controller: _descriptionController,
              hint: 'Describe what happened, when, and how often.',
              maxLines: 5,
            ),
            AppSpacing.fieldGap.heightBox(),
            Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            10.h.heightBox(),
            ComplaintCategoryGrid(
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
            AppSpacing.fieldGap.heightBox(),
            Text(
              'Where did it happen?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            AppSpacing.fieldLabelGap.heightBox(),
            AppTextField(
              label: 'Location',
              controller: _locationController,
              hint: 'Tower A ï¿½ Level 12 ï¿½ Corridor',
            ),
            AppSpacing.fieldGap.heightBox(),
            Text(
              'Priority',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            10.h.heightBox(),
            AppSegmentedControl<ComplaintPriority>(
              label: null,
              segments: {
                ComplaintPriority.low: 'Low',
                ComplaintPriority.medium: 'Medium',
                ComplaintPriority.high: 'High',
              },
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            10.h.heightBox(),
            SwitchListTile.adaptive(
              key: Key('complaint-anonymous-switch'),
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value),
              title: Text(
                'Submit anonymously',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
              ),
              subtitle: Text(
                'Your name will not be shown to the reported party.',
                style: TextStyle(fontSize: 11.sp),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            18.h.heightBox(),
            FilledButton.icon(
              key: Key('submit-complaint'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              icon: controller.isSubmitting.value
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onBrand,
                      ),
                    )
                  : Icon(Icons.send_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Submitting...'
                    : 'Submit complaint',
              ),
              style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52)),
            ),
            if (_error.isNotEmpty) ...[
              10.h.heightBox(),
              Text(_error, style: TextStyle(color: AppPalette.danger)),
            ],
            if (controller.errorMessage.value != null) ...[
              10.h.heightBox(),
              Text(
                controller.errorMessage.value!,
                style: TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    _error = '';
    if (_subjectController.text.trim().length < 4) {
      setState(() => _error = 'Add a short subject for the complaint.');
      return;
    }
    if (_descriptionController.text.trim().length < 10) {
      setState(() => _error = 'Describe the issue in a little more detail.');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Submit complaint?',
      message:
          'The community team will review "${_subjectController.text.trim()}" '
          'and update you here.',
      confirmLabel: 'Submit',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final complaint = await controller.fileComplaint(
      category: _category,
      subject: _subjectController.text,
      description: _descriptionController.text,
      location: _locationController.text.trim().isEmpty
          ? 'Tower A Â· 1205'
          : _locationController.text,
      priority: _priority,
      isAnonymous: _isAnonymous,
    );
    if (!mounted) {
      return;
    }
    if (complaint == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'Submission failed.';
      });
      return;
    }
    Get.offNamed(AppRoutes.complaintDetail, arguments: complaint);
  }
}
