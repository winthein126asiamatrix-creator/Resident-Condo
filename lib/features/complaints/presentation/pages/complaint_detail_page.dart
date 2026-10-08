import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.fromLTRB(
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
                  'Filed ${current.createdOn} · ${current.category.label}',
              trailing: ComplaintStatusPill(status: current.status),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'What you reported',
              child: Text(
                current.description,
                style: TextStyle(color: tokens.mutedStrong, height: 1.45),
              ),
            ),
            if (current.resolution != null) ...[
              const SizedBox(height: 16),
              AppSectionCard(
                title: 'Resolution',
                child: Text(
                  current.resolution!,
                  style: const TextStyle(
                    color: AppPalette.success,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppSectionHeader(
              title: 'Conversation',
              count: current.comments.length,
            ),
            const SizedBox(height: 10),
            if (current.comments.isEmpty)
              Text(
                'No messages yet. The community team will reply here.',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              )
            else
              for (final comment in current.comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CommentTile(comment: comment),
                ),
            if (current.isOpen) ...[
              const SizedBox(height: 10),
              _MessageBox(controller: controller, complaint: current),
            ],
            if (current.canWithdraw) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _withdraw(context, current),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Withdraw complaint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: const BorderSide(color: Color(0xFFF0C6C0)),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isStaff ? tokens.brandTint : tokens.surface,
        borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                comment.postedOn,
                style: TextStyle(color: tokens.faint, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            comment.authorRole,
            style: TextStyle(color: tokens.muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            comment.message,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12,
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
          fieldKey: const Key('complaint-message-field'),
          label: 'Reply to the team',
          controller: _message,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          hint: 'Reply to the community team…',
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('send-complaint-message'),
            onPressed: widget.controller.isSubmitting.value ? null : _send,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send message'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
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
