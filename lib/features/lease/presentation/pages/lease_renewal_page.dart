import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/lease.dart';
import '../controllers/lease_controller.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_form_field.dart';

class LeaseRenewalPage extends StatefulWidget {
  const LeaseRenewalPage({super.key});

  @override
  State<LeaseRenewalPage> createState() => _LeaseRenewalPageState();
}

class _LeaseRenewalPageState extends State<LeaseRenewalPage> {
  final LeaseController controller = Get.find<LeaseController>();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  bool _seeded = false;
  String _error = '';

  /// The day after the current term ends, which is the earliest sensible start
  /// for a renewal and the day the form opens on.
  static DateTime _firstRenewalDay(Lease lease) =>
      AppDates.dateOnly(lease.endDate).add(const Duration(days: 1));

  /// Quick lengths, counted from the chosen start. A term usually ends the day
  /// before the anniversary, so each option lands there. A year is the usual ask
  /// and is what the form starts on.
  static List<_DatePreset> _endPresets(DateTime start) {
    return [
      for (final months in const [4, 6, 12])
        _DatePreset(
          AppDates.addMonths(start, months).subtract(const Duration(days: 1)),
          '+$months months',
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seed(controller.selectedLease.value);
  }

  /// Fills the form in once, from whichever lease is open. Called both on the
  /// first build and whenever a lease arrives after the page was mounted, so the
  /// form is never read before it has dates in it.
  void _seed(Lease? lease) {
    if (_seeded || lease == null) {
      return;
    }
    _seeded = true;
    _start = _firstRenewalDay(lease);
    _end = _endPresets(_start).last.value;
    _rentController.text = (lease.monthlyRent * 1.03).round().toString();
  }

  @override
  void dispose() {
    _rentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lease = controller.selectedLease.value;
      if (lease == null) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Lease renewal'),
          body: AppStateMessage(
            title: 'No lease selected',
            message: 'Open your lease before requesting a renewal.',
            icon: Icons.description_outlined,
            actionLabel: 'Back to lease',
            onAction: () => Get.offNamed(AppRoutes.lease),
          ),
        );
      }

      _seed(lease);

      return Scaffold(
        appBar: AppDetailAppBar(title: 'Lease renewal'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            AppCard(
              color: AppPalette.brandTint,
              borderColor: AppPalette.brandSoft,
              child: Row(
                children: [
                  const AppIconTile(
                    icon: Icons.autorenew_rounded,
                    color: AppPalette.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current term',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${AppDates.format(lease.startDate)} → '
                          '${AppDates.format(lease.endDate)}',
                          style: const TextStyle(
                            color: AppPalette.mutedStrong,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${AppFormatters.currency(lease.monthlyRent)} / month · '
                          '${lease.daysRemaining} days left',
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Proposed term',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _TermPicker(
              lease: lease,
              start: _start,
              end: _end,
              endPresets: _endPresets(_start),
              onEndSelected: (value) => setState(() {
                _end = value;
                _error = '';
              }),
              onPickStart: () => _pickCustomStart(lease),
              onPickEnd: _pickCustomEnd,
              durationLabel: _durationLabel(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Proposed monthly rent',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            AppTextField(
              fieldKey: const Key('renewal-rent-field'),
              label: 'Proposed monthly rent',
              controller: _rentController,
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              hint: '2400',
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Note (optional)',
              controller: _noteController,
              maxLines: 3,
              hint: 'Add context for the other party…',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('submit-renewal'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              icon: controller.isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Sending request...'
                    : 'Send renewal request',
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
      );
    });
  }

  Future<void> _submit() async {
    _error = '';
    final rent = double.tryParse(_rentController.text.trim());
    if (rent == null || rent <= 0) {
      setState(() => _error = 'Enter the proposed monthly rent.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'The end date must be after the start date.');
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Send renewal request?',
      message:
          'Propose ${AppFormatters.currency(rent)} per month from '
          '${AppDates.format(_start)} to ${AppDates.format(_end)} '
          '(${_durationLabel()}).',
      confirmLabel: 'Send request',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final lease = controller.selectedLease.value;
    if (lease == null) {
      return;
    }

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: _start,
      proposedEnd: _end,
      proposedRent: rent,
      note: _noteController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (renewal == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'The request failed.';
      });
      return;
    }
    Get.offNamed(AppRoutes.leaseRenewalSent, arguments: renewal);
  }

  /// Opens the calendar for the start date. Any day the resident has not been
  /// offered as a quick option can be picked here.
  Future<void> _pickCustomStart(Lease lease) async {
    final first = AppDates.dateOnly(lease.startDate);
    final last = AppDates.dateOnly(_end).isAfter(first)
        ? AppDates.dateOnly(_end)
        : first;
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(first) || _start.isAfter(last)
          ? first
          : _start,
      firstDate: first,
      lastDate: last,
      helpText: 'New start date',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      // The resident has already chosen how long they want, so moving the start
      // moves the end by the same number of days and keeps the term intact.
      final span = AppDates.daysBetween(_start, _end).clamp(1, 36500);
      _start = AppDates.dateOnly(picked);
      _end = _start.add(Duration(days: span));
      _error = '';
    });
  }

  /// Opens the calendar for the end date, bounded to a real term after the
  /// chosen start.
  Future<void> _pickCustomEnd() async {
    final first = _start.add(const Duration(days: 1));
    final last = AppDates.addMonths(_start, 120);
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(first) || _end.isAfter(last) ? first : _end,
      firstDate: first,
      lastDate: last,
      helpText: 'New end date',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _end = AppDates.dateOnly(picked);
      _error = '';
    });
  }

  /// How long the proposed term is, in the words the resident would use.
  String _durationLabel() {
    final months = AppDates.monthsBetween(_start, _end);
    final days = AppDates.inclusiveDaysBetween(_start, _end);
    final parts = <String>[];
    if (months == 12) {
      parts.add('1 year');
    } else if (months > 12 && months % 12 == 0) {
      parts.add('${months ~/ 12} years');
    } else if (months > 0) {
      parts.add('$months month${months == 1 ? '' : 's'}');
    }
    parts.add('$days day${days == 1 ? '' : 's'}');
    return parts.join(' · ');
  }
}

/// A quick date option: the day itself, plus the shorthand a resident would use
/// to ask for it.
@immutable
class _DatePreset {
  const _DatePreset(this.value, this.label);

  final DateTime value;
  final String label;
}

/// The term a resident is proposing: both dates, how long they add up to, and
/// the quick ways of setting its length.
///
/// Both tiles open the calendar, so any day can be chosen, and the quick lengths
/// below them cover the terms people actually ask for. The duration strip sits
/// between the two dates so it always reflects the pair above it.
class _TermPicker extends StatelessWidget {
  const _TermPicker({
    required this.lease,
    required this.start,
    required this.end,
    required this.endPresets,
    required this.onEndSelected,
    required this.onPickStart,
    required this.onPickEnd,
    required this.durationLabel,
  });

  final Lease lease;
  final DateTime start;
  final DateTime end;
  final List<_DatePreset> endPresets;
  final ValueChanged<DateTime> onEndSelected;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _DateTile(
                      fieldKey: const Key('renewal-start-date'),
                      caption: 'Starts',
                      value: start,
                      onTap: onPickStart,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppPalette.faint,
                    ),
                  ),
                  Expanded(
                    child: _DateTile(
                      fieldKey: const Key('renewal-end-date'),
                      caption: 'Ends',
                      value: end,
                      onTap: onPickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DurationStrip(lease: lease, start: start, label: durationLabel),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Quick lengths',
          style: TextStyle(
            color: AppPalette.mutedStrong,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _QuickDateRow(
          presets: endPresets,
          selected: end,
          onSelected: onEndSelected,
        ),
      ],
    );
  }
}

/// One end of the term. Tapping it opens the calendar for any date at all.
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.fieldKey,
    required this.caption,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String caption;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      key: fieldKey,
      color: AppPalette.surfaceMuted,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                caption.toUpperCase(),
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              // Shrinks rather than wraps, so a long date never breaks the row.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppDates.format(value),
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppDates.weekday(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 13,
                    color: AppPalette.brand,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Pick a date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The running total for the pair above it: how long the term is, and how its
/// start lines up with the term it replaces.
class _DurationStrip extends StatelessWidget {
  const _DurationStrip({
    required this.lease,
    required this.start,
    required this.label,
  });

  final Lease lease;
  final DateTime start;
  final String label;

  /// Plain wording for where the new term begins, so an overlap or a long gap
  /// is never left for the resident to work out.
  String get _timing {
    final gap = AppDates.daysBetween(lease.endDate, start);
    if (gap > 1) {
      return 'Starts $gap days after the current term ends';
    }
    if (gap == 1) {
      return 'Starts the day after the current term ends';
    }
    if (gap == 0) {
      return 'Starts on the day the current term ends';
    }
    return 'Overlaps the current term by ${gap.abs()} days';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timelapse_rounded,
            size: 18,
            color: AppPalette.brand,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timing,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppPalette.mutedStrong,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The quick lengths for the term, each showing the day it lands on.
class _QuickDateRow extends StatelessWidget {
  const _QuickDateRow({
    required this.presets,
    required this.selected,
    required this.onSelected,
  });

  final List<_DatePreset> presets;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < presets.length; index++)
          _QuickDateChip(
            key: Key('renewal-length-$index'),
            preset: presets[index],
            selected: presets[index].value == selected,
            onTap: () => onSelected(presets[index].value),
          ),
      ],
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.preset,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _DatePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.label}, ${AppDates.format(preset.value)}',
      child: Material(
        color: selected ? AppPalette.brandTint : Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppPalette.brand : AppPalette.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.label,
                  style: TextStyle(
                    color: selected ? AppPalette.brand : AppPalette.mutedStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppDates.formatShort(preset.value),
                  style: TextStyle(
                    color: selected ? AppPalette.brandDark : AppPalette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
