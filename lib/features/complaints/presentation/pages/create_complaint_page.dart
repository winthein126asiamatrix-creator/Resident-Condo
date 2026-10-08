import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../domain/entities/complaint.dart';
import '../controllers/complaint_controller.dart';
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
            const Text(
              'What happened?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.fieldLabelGap),
            AppTextField(
              label: 'Subject',
              fieldKey: const Key('complaint-subject-field'),
              controller: _subjectController,
              hint: 'Short summary of the issue',
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const Text(
              'Details',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.fieldLabelGap),
            AppTextField(
              label: 'Description',
              fieldKey: const Key('complaint-description-field'),
              controller: _descriptionController,
              hint: 'Describe what happened, when, and how often.',
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ComplaintCategory.values
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: tokens.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const Text(
              'Where did it happen?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.fieldLabelGap),
            AppTextField(
              label: 'Location',
              controller: _locationController,
              hint: 'Tower A � Level 12 � Corridor',
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const Text(
              'Priority',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            AppSegmentedControl<ComplaintPriority>(
              label: null,
              segments: const {
                ComplaintPriority.low: 'Low',
                ComplaintPriority.medium: 'Medium',
                ComplaintPriority.high: 'High',
              },
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              key: const Key('complaint-anonymous-switch'),
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value),
              title: const Text(
                'Submit anonymously',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: const Text(
                'Your name will not be shown to the reported party.',
                style: TextStyle(fontSize: 11),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('submit-complaint'),
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
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Submitting...'
                    : 'Submit complaint',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: AppPalette.danger)),
            ],
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: AppPalette.danger),
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
          ? 'Tower A · 1205'
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
