import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_primary_action.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../domain/entities/facility.dart';

import '../controllers/facility_controller.dart';

import '../widgets/facility_labels.dart';

import '../../../../core/utils/app_dates.dart';

import '../../../../core/utils/app_times.dart';

class FacilityReservationPage extends GetView<FacilityController> {
  const FacilityReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Reserve facility',
        subtitle: 'Choose your date, time and duration',
        onBack: () => Get.back<void>(),
      ),
      body: Obx(() {
        final tokens = AppThemeTokens.of(context);
        final facility = controller.selectedFacility.value;
        if (facility == null) {
          return AppStateMessage(
            title: 'No facility selected',
            message: 'Choose a facility before continuing.',
            icon: Icons.event_available_outlined,
            actionLabel: 'Back to facilities',
            onAction: () => Get.offNamed(AppRoutes.home),
          );
        }
        return ListView(
          key: Key('facility-reservation-scroll'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            AppSpacing.pageBottom,
          ),
          children: [
            _SelectedFacilityCard(facility: facility),
            AppSpacing.sectionGap.h.heightBox(),
            _SectionLabel(label: 'Select a date'),
            AppSpacing.fieldLabelGap.h.heightBox(),
            _DateSelector(
              dates: controller.reservationDates,
              selected: controller.selectedDate.value,
              onSelected: controller.selectDate,
            ),
            AppSpacing.sectionGap.h.heightBox(),
            _SectionLabel(label: 'Start time'),
            AppSpacing.fieldLabelGap.h.heightBox(),
            _SlotSelector(
              facility: facility,
              selected: controller.selectedStartTimeLabel,
              customTimeSelected: controller.isCustomTimeSelected,
              onSelected: controller.selectSlot,
              onPickCustomTime: () => _pickCustomTime(context),
            ),
            AppSpacing.sectionGap.h.heightBox(),
            _SectionLabel(label: 'Duration'),
            AppSpacing.fieldLabelGap.h.heightBox(),
            _DurationSelector(
              selected: controller.selectedDurationHours.value,
              onSelected: controller.selectDuration,
            ),
            12.h.heightBox(),
            _ReservationInterval(
              range: controller.reservationRange,
              error: controller.durationError,
            ),
            20.h.heightBox(),
            _BookingSummary(
              facility: facility,
              date: controller.selectedDateLong,
              startTime: controller.selectedStartTimeLabel,
              durationHours: controller.selectedDurationHours.value,
              range: controller.reservationRange,
            ),
            24.h.heightBox(),
            AppPrimaryAction(
              key: Key('confirm-reservation'),
              onPressed: controller.canConfirmBooking
                  ? () => _confirm(context)
                  : null,
              isLoading: controller.isBooking.value,
              label: 'Confirm Reservation',
              icon: Icons.event_available_rounded,
            ),
            if (!controller.canConfirmBooking) ...[
              10.h.heightBox(),
              Text(
                controller.durationError ??
                    'Choose a date and a start time to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: controller.durationError == null
                      ? tokens.muted
                      : AppPalette.danger,
                  fontSize: 12.5.sp,
                  fontWeight: controller.durationError == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _pickCustomTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          controller.customTime.value ?? TimeOfDay(hour: 18, minute: 0),
      helpText: 'Choose a custom time',
    );
    if (picked == null) {
      return;
    }
    controller.selectCustomTime(picked);
  }

  Future<void> _confirm(BuildContext context) async {
    final facility = controller.selectedFacility.value;
    final range = controller.reservationRange;
    final start = controller.selectedStartTimeLabel;
    if (facility == null || range == null || start == null) {
      return;
    }
    controller.errorMessage.value = null;

    final confirmed = await showAppConfirmSummaryDialog(
      context,
      title: 'Confirm Reservation',
      message: 'Please review your reservation details before confirming.',
      icon: Icons.event_available_rounded,
      summary: [
        AppSummaryRow(
          label: 'Facility',
          value: displayFacilityName(facility.name),
          emphasis: true,
        ),
        AppSummaryRow(label: 'Date', value: controller.selectedDateLong),
        AppSummaryRow(label: 'Start time', value: start),
        AppSummaryRow(
          label: 'Duration',
          value: controller.selectedDurationHours.value == 1
              ? '1 hour'
              : '${controller.selectedDurationHours.value} hours',
        ),
        AppSummaryRow(label: 'Reservation time', value: range.label),
      ],
      confirmLabel: 'Confirm Reservation',
      onConfirm: () async {
        final reservation = await controller.bookSelectedSlot();
        if (reservation == null) {
          return AppConfirmResult.failure(
            controller.errorMessage.value ??
                'Unable to complete the reservation.',
          );
        }
        return AppConfirmResult.success();
      },
    );

    if (!confirmed) {
      return;
    }
    final reservation = controller.bookingSuccess.value;
    if (reservation != null) {
      Get.offNamed(AppRoutes.bookingConfirmed, arguments: reservation);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Text(
      label,
      style: TextStyle(
        color: tokens.ink,
        fontSize: 16.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _SelectedFacilityCard extends StatelessWidget {
  const _SelectedFacilityCard({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final available = facility.availableSlots.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.brandBorder),
        boxShadow: tokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  facility.imagePath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Container(
                    color: tokens.brand,
                    child: Icon(
                      Icons.apartment_rounded,
                      color: Colors.white70,
                      size: 34,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x55000000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          14.w.widthBox(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayFacilityName(facility.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  4.h.heightBox(),
                  Text(
                    facility.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.mutedStrong, fontSize: 12.sp),
                  ),
                  8.h.heightBox(),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: tokens.muted,
                      ),
                      4.w.widthBox(),
                      Expanded(
                        child: Text(
                          facility.openingHours,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  8.h.heightBox(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: available
                          ? Color(0xFF087F5B).withValues(alpha: 0.1)
                          : Color(0xFFC2410C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      available
                          ? '${facility.availableSlots.length} slots available'
                          : 'Fully booked',
                      style: TextStyle(
                        color: available
                            ? Color(0xFF087F5B)
                            : Color(0xFFC2410C),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          12.w.widthBox(),
        ],
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.dates,
    required this.selected,
    required this.onSelected,
  });

  final List<String> dates;
  final String selected;
  final ValueChanged<String> onSelected;

  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => 8.w.widthBox(),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date == selected;
          final parsed = AppDates.parse(date);
          final weekday = AppDates.weekday(parsed).substring(0, 3);
          return _DateChip(
            key: Key('facility-date-$date'),
            weekday: weekday,
            day: parsed.day.toString(),
            month: _months[parsed.month - 1],
            selected: isSelected,
            tokens: tokens,
            onTap: () {
              vibrateNow();
              onSelected(date);
            },
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    super.key,
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final AppThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tokens.brand : tokens.surface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: 62,
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: selected ? tokens.brand : tokens.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday.toUpperCase(),
                style: TextStyle(
                  color: selected ? tokens.onBrand : tokens.muted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              4.h.heightBox(),
              Text(
                day,
                style: TextStyle(
                  color: selected ? tokens.onBrand : tokens.ink,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              4.h.heightBox(),
              Text(
                month,
                style: TextStyle(
                  color: selected
                      ? tokens.onBrand.withValues(alpha: 0.85)
                      : tokens.muted,
                  fontSize: 10.sp,
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

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hours in FacilityController.reservationDurations)
          _SelectableChip(
            key: Key('facility-duration-$hours'),
            label: hours == 1 ? '1 hour' : '$hours hours',
            selected: hours == selected,
            tokens: tokens,
            onTap: () {
              vibrateNow();
              onSelected(hours);
            },
          ),
      ],
    );
  }
}

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({
    required this.facility,
    required this.selected,
    required this.customTimeSelected,
    required this.onSelected,
    required this.onPickCustomTime,
  });

  final Facility facility;
  final String? selected;
  final bool customTimeSelected;
  final ValueChanged<String> onSelected;
  final VoidCallback onPickCustomTime;

  static const _customLabel = 'Custom time';

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in facility.availableSlots)
          _SelectableChip(
            key: Key('facility-slot-$slot'),
            label: slot,
            selected: slot == selected && !customTimeSelected,
            tokens: tokens,
            onTap: () {
              vibrateNow();
              onSelected(slot);
            },
          ),
        _SelectableChip(
          key: Key('facility-slot-custom'),
          label: customTimeSelected && selected != null
              ? selected!
              : _customLabel,
          leading: Icons.schedule_rounded,
          selected: customTimeSelected,
          tokens: tokens,
          onTap: () {
            vibrateNow();
            onPickCustomTime();
          },
        ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final AppThemeTokens tokens;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tokens.brand : tokens.surface,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected ? tokens.brand : tokens.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 16,
                  color: selected ? tokens.onBrand : tokens.mutedStrong,
                ),
                6.w.widthBox(),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? tokens.onBrand : tokens.ink,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationInterval extends StatelessWidget {
  const _ReservationInterval({required this.range, required this.error});

  final AppTimeRange? range;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: hasError
            ? AppPalette.danger.withValues(alpha: 0.06)
            : tokens.brandTint,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasError
              ? AppPalette.danger.withValues(alpha: 0.3)
              : tokens.brandBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.error_outline_rounded : Icons.schedule_rounded,
            size: 18,
            color: hasError ? AppPalette.danger : tokens.brand,
          ),
          10.w.widthBox(),
          Expanded(
            child: hasError
                ? Text(
                    error!,
                    style: TextStyle(
                      color: AppPalette.danger,
                      fontSize: 12.5.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    range == null
                        ? 'Pick a start time to see your time range.'
                        : range!.label,
                    style: TextStyle(
                      color: range == null ? tokens.muted : tokens.brand,
                      fontSize: range == null ? 12.5 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.facility,
    required this.date,
    required this.startTime,
    required this.durationHours,
    required this.range,
  });

  final Facility facility;
  final String date;
  final String? startTime;
  final int durationHours;
  final AppTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 18, color: tokens.brand),
              8.w.widthBox(),
              Text(
                'Reservation summary',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          12.h.heightBox(),
          _SummaryRow(label: 'Facility', value: displayFacilityName(facility.name)),
          _SummaryRow(label: 'Date', value: date),
          _SummaryRow(
            label: 'Start time',
            value: startTime ?? 'Not selected',
            muted: startTime == null,
          ),
          _SummaryRow(
            label: 'Duration',
            value: durationHours == 1 ? '1 hour' : '$durationHours hours',
          ),
          _SummaryRow(
            label: 'Reservation time',
            value: range?.label ?? 'Not selected',
            muted: range == null,
            emphasis: range != null,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool muted;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 13.sp),
            ),
          ),
          12.w.widthBox(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: muted
                    ? tokens.muted
                    : (emphasis ? tokens.brand : tokens.ink),
                fontSize: 13.5.sp,
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
