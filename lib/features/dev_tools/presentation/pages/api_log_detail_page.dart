import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_log_store.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';

class ApiLogDetailPage extends StatelessWidget {
  const ApiLogDetailPage({required this.logId, super.key});

  final String logId;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ApiLogStore>()) {
      return const Scaffold(
        body: AppStateMessage(
          title: 'Log unavailable',
          message: 'The dev logger is not enabled for this build.',
          icon: Icons.terminal_rounded,
        ),
      );
    }
    final store = Get.find<ApiLogStore>();
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Request detail',
        subtitle: logId,
        showBackButton: true,
      ),
      body: Obx(() {
        final log = store.findById(logId);
        if (log == null) {
          return const AppStateMessage(
            title: 'Log removed',
            message: 'This request is no longer in the log store.',
            icon: Icons.delete_sweep_outlined,
          );
        }
        return _DetailBody(log: log);
      }),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.log});

  final ApiLogEntry log;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final statusColor = _statusColor(log, tokens);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.pageTop,
        AppSpacing.gutter,
        AppSpacing.pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Overview',
            icon: Icons.info_outline_rounded,
            children: [
              Row(
                children: [
                  AppStatusPill(
                    label: log.method,
                    color: _methodColor(log.method),
                  ),
                  if (log.label != null) ...[
                    8.w.widthBox(),
                    AppStatusPill(label: log.label!, color: AppPalette.info),
                  ],
                  const Spacer(),
                  AppStatusPill(
                    label: log.isSuccess
                        ? 'Success'
                        : log.isFailed
                        ? 'Failed'
                        : 'Pending',
                    color: statusColor,
                    icon: log.isSuccess
                        ? Icons.check_circle_outline_rounded
                        : log.isFailed
                        ? Icons.error_outline_rounded
                        : Icons.hourglass_empty_rounded,
                  ),
                ],
              ),
              14.h.heightBox(),
              _InfoRow(label: 'Method', value: log.method),
              _InfoRow(
                label: 'Status',
                value: log.statusCode?.toString() ?? '—',
                valueColor: statusColor,
              ),
              _InfoRow(
                label: 'Duration',
                value: log.durationMs == null ? '—' : '${log.durationMs} ms',
              ),
              _InfoRow(
                label: 'Requested',
                value: _dateTime(log.requestTimestamp),
              ),
              if (log.responseTimestamp != null)
                _InfoRow(
                  label: 'Responded',
                  value: _dateTime(log.responseTimestamp!),
                ),
              _InfoRow(
                label: 'URL',
                value: log.url,
                copyValue: log.url,
                copyLabel: 'URL',
              ),
              if (log.requestContentType != null)
                _InfoRow(label: 'Content type', value: log.requestContentType!),
              _InfoRow(
                label: 'Request size',
                value: log.requestSize == null ? '—' : '${log.requestSize} B',
              ),
              _InfoRow(
                label: 'Response size',
                value: log.responseSize == null ? '—' : '${log.responseSize} B',
              ),
            ],
          ),
          14.h.heightBox(),
          _SectionCard(
            title: 'Request',
            icon: Icons.upload_rounded,
            copyValue: _body(log.requestBody),
            copyLabel: 'request body',
            children: [
              _LabelValueBlock(
                label: 'Headers',
                value: _json(log.requestHeaders),
              ),
              12.h.heightBox(),
              _LabelValueBlock(
                label: 'Query parameters',
                value: _json(log.queryParameters),
              ),
              12.h.heightBox(),
              _LabelValueBlock(label: 'Body', value: _body(log.requestBody)),
            ],
          ),
          14.h.heightBox(),
          _SectionCard(
            title: 'Response',
            icon: Icons.download_rounded,
            copyValue: log.responseBody == null
                ? null
                : _body(log.responseBody),
            copyLabel: 'response body',
            children: [
              _LabelValueBlock(
                label: 'Headers',
                value: _json(log.responseHeaders),
              ),
              12.h.heightBox(),
              _LabelValueBlock(
                label: 'Body',
                value: log.responseBody == null && log.isPending
                    ? 'Waiting for the response…'
                    : _body(log.responseBody),
              ),
            ],
          ),
          if (log.isFailed) ...[
            14.h.heightBox(),
            _SectionCard(
              title: 'Error',
              icon: Icons.error_outline_rounded,
              copyValue: _errorDetails(log),
              copyLabel: 'error details',
              children: [
                _InfoRow(
                  label: 'DioException',
                  value: log.dioExceptionType ?? '—',
                ),
                _InfoRow(label: 'Message', value: log.errorMessage ?? '—'),
                12.h.heightBox(),
                _LabelValueBlock(
                  label: 'Stack trace',
                  value: log.stackTrace ?? 'Not available',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.copyValue,
    this.copyLabel,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? copyValue;
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.brand),
              8.w.widthBox(),
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
              if (copyValue != null)
                IconButton(
                  tooltip: 'Copy $copyLabel',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _copy(context, copyLabel ?? title, copyValue!),
                  icon: Icon(
                    Icons.copy_all_rounded,
                    size: 18,
                    color: tokens.muted,
                  ),
                ),
            ],
          ),
          8.h.heightBox(),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyValue,
    this.copyLabel,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? copyValue;
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: valueColor ?? tokens.ink,
                fontSize: 12.5.sp,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyValue != null)
            InkWell(
              onTap: () => _copy(context, copyLabel ?? label, copyValue!),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 16, color: tokens.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelValueBlock extends StatelessWidget {
  const _LabelValueBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.mutedStrong,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        6.h.heightBox(),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: SelectableText(
            value,
            style: TextStyle(
              color: tokens.ink,
              fontSize: 11.5.sp,
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

String _json(Object? value) {
  if (value == null) {
    return 'None';
  }
  if (value is Map && value.isEmpty) {
    return 'None';
  }
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

String _body(Object? value) {
  if (value == null) {
    return 'No body';
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'No body';
    }
    try {
      final decoded = jsonDecode(trimmed);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value;
    }
  }
  return _json(value);
}

String _errorDetails(ApiLogEntry log) {
  return <String>[
    'Status: ${log.statusCode ?? '—'}',
    'DioException: ${log.dioExceptionType ?? '—'}',
    'Message: ${log.errorMessage ?? '—'}',
    if (log.stackTrace != null) '',
    if (log.stackTrace != null) 'Stack trace:',
    if (log.stackTrace != null) log.stackTrace!,
  ].join('\n');
}

Future<void> _copy(BuildContext context, String label, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Copied $label'),
      ),
    );
}

Color _methodColor(String method) => switch (method) {
  'GET' => AppPalette.info,
  'POST' => AppPalette.success,
  'PUT' => AppPalette.warning,
  'PATCH' => AppPalette.info,
  'DELETE' => AppPalette.danger,
  _ => AppPalette.mutedStrong,
};

Color _statusColor(ApiLogEntry log, AppThemeTokens tokens) {
  if (log.isPending) {
    return tokens.faint;
  }
  final status = log.statusCode;
  if (status == null || status >= 500) {
    return AppPalette.danger;
  }
  if (status >= 400) {
    return AppPalette.warning;
  }
  if (status >= 200 && status < 300) {
    return AppPalette.success;
  }
  return AppPalette.warning;
}

String _dateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.'
      '${value.millisecond.toString().padLeft(3, '0')}';
}
