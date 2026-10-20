import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/complaint.dart';

import '../controllers/complaint_controller.dart';

import '../widgets/complaint_widgets.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/widgets/app_form_field.dart';

class ComplaintDetailPage extends GetView<ComplaintController> {
  const ComplaintDetailPage({required this.complaint, super.key});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Obx(() {
      final current = _current();
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Complaint'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            AppHeroPanel(
              icon: Icons.report_gmailerrorred_rounded,
              title: current.reference,
              subtitle: current.subject,
              footnote:
                  'Filed ${current.createdOn} Â· ${current.category.label}',
              trailing: ComplaintStatusPill(status: current.status),
            ),
            18.h.heightBox(),
            AppSectionCard(
              title: 'Details',
              child: Column(
                children: [
                  AppLabelValueRow(label: 'Location', value: current.location),
                  AppLabelValueRow(
                    label: 'Priority',
                    value: current.priority.label,
                  ),
                  AppLabelValueRow(
                    label: 'Assigned to',
                    value: current.assignedTo ?? 'Pending assignment',
                  ),
                  AppLabelValueRow(
                    label: 'Last update',
                    value: current.updatedOn,
                  ),
                ],
              ),
            ),
            16.h.heightBox(),
            AppSectionCard(
              title: 'What you reported',
              child: Text(
                current.description,
                style: TextStyle(color: tokens.mutedStrong, height: 1.45),
              ),
            ),
            if (current.resolution != null) ...[
              16.h.heightBox(),
              AppSectionCard(
                title: 'Resolution',
                child: Text(
                  current.resolution!,
                  style: TextStyle(
                    color: AppPalette.success,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            18.h.heightBox(),
            AppSectionHeader(
              title: 'Conversation',
              count: current.comments.length,
            ),
            10.h.heightBox(),
            if (current.comments.isEmpty)
              Text(
                'No messages yet. The community team will reply here.',
                style: TextStyle(color: tokens.muted, fontSize: 12.sp),
              )
            else
              for (final comment in current.comments)
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _CommentTile(comment: comment),
                ),
            if (current.isOpen) ...[
              10.h.heightBox(),
              _MessageBox(controller: controller, complaint: current),
            ],
            if (current.canWithdraw) ...[
              16.h.heightBox(),
              OutlinedButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _withdraw(context, current),
                icon: Icon(Icons.undo_rounded, size: 18),
                label: Text('Withdraw complaint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: BorderSide(color: Color(0xFFF0C6C0)),
                  minimumSize: Size.fromHeight(50),
                ),
              ),
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
      );
    });
  }

  Complaint _current() {
    return controller.complaints.firstWhere(
      (item) => item.id == complaint.id,
      orElse: () => complaint,
    );
  }

  Future<void> _withdraw(BuildContext context, Complaint current) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Withdraw complaint?',
      message:
          'Complaint ${current.reference} will be closed and cannot be reopened.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.withdraw(current);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to withdraw' : 'Complaint withdrawn',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : '${updated.reference} is now closed.',
      isError: updated == null,
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final ComplaintComment comment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isStaff = comment.authorRole == 'Resident';
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isStaff ? tokens.brandTint : tokens.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isStaff ? tokens.brandSoft : tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.author,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              Text(
                comment.postedOn,
                style: TextStyle(color: tokens.faint, fontSize: 10.sp),
              ),
            ],
          ),
          3.h.heightBox(),
          Text(
            comment.authorRole,
            style: TextStyle(color: tokens.muted, fontSize: 10.sp),
          ),
          8.h.heightBox(),
          Text(
            comment.message,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatefulWidget {
  const _MessageBox({required this.controller, required this.complaint});
  final ComplaintController controller;
  final Complaint complaint;

  @override
  State<_MessageBox> createState() => _MessageBoxState();
}

class _MessageBoxState extends State<_MessageBox> {
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          fieldKey: Key('complaint-message-field'),
          label: 'Reply to the team',
          controller: _message,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          hint: 'Reply to the community teamâ€¦',
        ),
        10.h.heightBox(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: Key('send-complaint-message'),
            onPressed: widget.controller.isSubmitting.value ? null : _send,
            icon: Icon(Icons.send_rounded, size: 18),
            label: Text('Send message'),
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(48)),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      return;
    }
    final updated = await widget.controller.addComment(
      widget.complaint,
      _message.text,
    );
    if (!mounted) {
      return;
    }
    if (updated != null) {
      _message.clear();
      showAppFeedback(
        context,
        title: 'Message sent',
        message: 'The community team will reply here.',
        isError: false,
      );
    } else {
      showAppFeedback(
        context,
        title: 'Unable to send',
        message: widget.controller.errorMessage.value ?? 'Please try again.',
        isError: true,
      );
    }
  }
}
