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

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_form_field.dart';

import '../../../../core/theme/app_radius.dart';

import '../../../../core/widgets/app_segmented_control.dart';

import '../../../../core/theme/app_spacing.dart';

class _CategoryBottomSheet extends StatelessWidget {
  const _CategoryBottomSheet({
    required this.currentCategory,
    required this.onSelected,
  });

  final ComplaintCategory currentCategory;
  final ValueChanged<ComplaintCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          16.h.heightBox(),
          Row(
            children: [
              Icon(Icons.category_rounded, color: tokens.brand, size: 22),
              10.w.widthBox(),
              Text(
                'Select Category',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          16.h.heightBox(),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: ComplaintCategory.values.map((category) {
              final isSelected = category == currentCategory;
              return _CategoryCard(
                category: category,
                isSelected: isSelected,
                onTap: () => onSelected(category),
              );
            }).toList(),
          ),
          8.h.heightBox(),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final ComplaintCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: category.label,
      child: Material(
        color: isSelected ? tokens.brandTint : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isSelected ? tokens.brand : tokens.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.brand : tokens.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category.icon,
                    size: 22,
                    color: isSelected ? tokens.onBrand : tokens.brand,
                  ),
                ),
                8.h.heightBox(),
                Flexible(
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? tokens.brand : tokens.ink,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
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
            InkWell(
              onTap: () => _showCategoryBottomSheet(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.brandTint,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        _category.icon,
                        size: 20,
                        color: tokens.brand,
                      ),
                    ),
                    12.w.widthBox(),
                    Expanded(
                      child: Text(
                        _category.label,
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: tokens.mutedStrong,
                      size: 22,
                    ),
                  ],
                ),
              ),
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

  void _showCategoryBottomSheet(BuildContext context) {
    showModalBottomSheet<ComplaintCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryBottomSheet(
        currentCategory: _category,
        onSelected: (category) {
          setState(() => _category = category);
          Navigator.pop(context);
        },
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
