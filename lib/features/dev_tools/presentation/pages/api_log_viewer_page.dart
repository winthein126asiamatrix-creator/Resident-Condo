import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_log_store.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/sized_box_extensions.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import 'api_log_detail_page.dart';

enum _LogFilter {
  all('All'),
  success('Success'),
  failed('Failed'),
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const _LogFilter(this.label);

  final String label;
}

class ApiLogViewerPage extends StatefulWidget {
  const ApiLogViewerPage({super.key});

  @override
  State<ApiLogViewerPage> createState() => _ApiLogViewerPageState();
}

class _ApiLogViewerPageState extends State<ApiLogViewerPage> {
  final _search = TextEditingController();
  _LogFilter _filter = _LogFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ApiLogStore>()) {
      return const Scaffold(
        body: AppStateMessage(
          title: 'API logs unavailable',
          message: 'The dev logger is not enabled for this build.',
          icon: Icons.terminal_rounded,
        ),
      );
    }
    final store = Get.find<ApiLogStore>();
    final tokens = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppDetailAppBar(
        title: 'API logs',
        subtitle: 'Live network activity from this session',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () => _clearLogs(context, store),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Obx(() {
        final visible = _visibleLogs(store);
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.pageTop,
                AppSpacing.gutter,
                0,
              ),
              child: _SummaryCard(store: store),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                14,
                AppSpacing.gutter,
                0,
              ),
              child: AppTextField(
                label: 'Search endpoint',
                hint: 'Path, URL or status',
                icon: Icons.search_rounded,
                controller: _search,
                maxLines: 1,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                suffixIconLabel: _search.text.isEmpty ? null : 'Clear search',
                onSuffixTap: () {
                  _search.clear();
                  setState(() {});
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                scrollDirection: Axis.horizontal,
                itemCount: _LogFilter.values.length,
                separatorBuilder: (_, _) => 8.w.widthBox(),
                itemBuilder: (context, index) {
                  final filter = _LogFilter.values[index];
                  return _FilterChip(
                    label: filter.label,
                    selected: _filter == filter,
                    onTap: () {
                      vibrateNow();
                      setState(() => _filter = filter);
                    },
                  );
                },
              ),
            ),
            10.h.heightBox(),
            Expanded(
              child: visible.isEmpty
                  ? AppStateMessage(
                      title: store.total == 0
                          ? 'No API calls yet'
                          : 'No matching calls',
                      message: store.total == 0
                          ? 'Requests made anywhere in the app will appear here.'
                          : 'Try a different filter or search term.',
                      icon: Icons.terminal_rounded,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        0,
                        AppSpacing.gutter,
                        AppSpacing.pageBottom,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          AppSpacing.cardGap.heightBox(),
                      itemBuilder: (context, index) {
                        final log = visible[index];
                        return _LogTile(
                          log: log,
                          onTap: () => Get.to<void>(
                            () => ApiLogDetailPage(logId: log.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  List<ApiLogEntry> _visibleLogs(ApiLogStore store) {
    final query = _search.text.trim().toLowerCase();
    return store.logs.reversed.where((log) {
      final matchesFilter = switch (_filter) {
        _LogFilter.all => true,
        _LogFilter.success => log.isSuccess,
        _LogFilter.failed => log.isFailed,
        _LogFilter.get => log.method == 'GET',
        _LogFilter.post => log.method == 'POST',
        _LogFilter.put => log.method == 'PUT',
        _LogFilter.patch => log.method == 'PATCH',
        _LogFilter.delete => log.method == 'DELETE',
      };
      if (!matchesFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return log.endpoint.toLowerCase().contains(query) ||
          log.url.toLowerCase().contains(query) ||
          '${log.statusCode ?? ''}'.contains(query) ||
          log.method.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _clearLogs(BuildContext context, ApiLogStore store) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Clear API logs?',
      message: 'This removes every captured request from this session.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (confirmed) {
      store.clear();
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.store});

  final ApiLogStore store;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final average = store.averageDurationMs;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          _Stat(label: 'Total', value: '${store.total}', color: tokens.ink),
          8.w.widthBox(),
          _Stat(
            label: 'Success',
            value: '${store.successCount}',
            color: AppPalette.success,
          ),
          8.w.widthBox(),
          _Stat(
            label: 'Failed',
            value: '${store.failedCount}',
            color: AppPalette.danger,
          ),
          8.w.widthBox(),
          _Stat(
            label: 'Avg time',
            value: average == null ? '—' : '${average.round()} ms',
            color: tokens.brand,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          3.h.heightBox(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.muted,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.brand : tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? tokens.brand : tokens.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tokens.onBrand : tokens.mutedStrong,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onTap});

  final ApiLogEntry log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final statusColor = _statusColor(log, tokens);
    return AppCard(
      padding: EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusPill(
                label: log.method,
                color: _methodColor(log.method),
                dense: true,
              ),
              8.w.widthBox(),
              Expanded(
                child: Text(
                  log.endpoint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              6.w.widthBox(),
              Text(
                log.statusCode?.toString() ?? '—',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          8.h.heightBox(),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              5.w.widthBox(),
              Text(
                log.isSuccess
                    ? 'Success'
                    : log.isFailed
                    ? 'Failed'
                    : 'Pending',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (log.label != null) ...[
                8.w.widthBox(),
                AppStatusPill(
                  label: log.label!,
                  color: AppPalette.info,
                  dense: true,
                ),
              ],
              const Spacer(),
              Text(
                log.durationMs == null ? '—' : '${log.durationMs} ms',
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              10.w.widthBox(),
              Text(
                _time(log.requestTimestamp),
                style: TextStyle(
                  color: tokens.faint,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
  if (status == null) {
    return AppPalette.danger;
  }
  if (status >= 500) {
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

String _time(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
