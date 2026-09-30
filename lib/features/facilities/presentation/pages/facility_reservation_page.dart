import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/facility.dart';
import '../controllers/facility_controller.dart';
import '../widgets/facility_labels.dart';
import '../../../../core/utils/app_times.dart';

class FacilityReservationPage extends GetView<FacilityController> {
  const FacilityReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The same custom bar the maintenance form uses, so the two screens are
      // indistinguishable at the top of the page.
      appBar: AppDetailAppBar(
        title: 'Reserve facility',
        subtitle: 'Pick a date and a time that suits you',
        onBack: () => Get.back<void>(),
      ),
      body: Obx(() {
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
          key: const Key('facility-reservation-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            _FacilityReservationIntro(facility: facility),
            const SizedBox(height: 22),
            const Text(
              'Select a date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _DateSelector(
              dates: controller.reservationDates,
              selected: controller.selectedDate.value,
              onSelected: controller.selectDate,
            ),
            const SizedBox(height: 22),
            const Text(
              'Start time',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _SlotSelector(
              facility: facility,
              selected: controller.selectedStartTimeLabel,
              customTimeSelected: controller.isCustomTimeSelected,
              onSelected: controller.selectSlot,
              onPickCustomTime: () => _pickCustomTime(context),
            ),
            const SizedBox(height: 22),
            const Text(
              'Duration',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _DurationSelector(
              selected: controller.selectedDurationHours.value,
              onSelected: controller.selectDuration,
            ),
            const SizedBox(height: 14),
            _ReservationInterval(
              range: controller.reservationRange,
              error: controller.durationError,
            ),
            const SizedBox(height: 24),
            // The CTA is the only way a reservation is created: picking a date,
            // a time or a duration never submits anything.
            AppPrimaryAction(
              key: const Key('confirm-reservation'),
              onPressed: controller.canConfirmBooking
                  ? () => _confirm(context)
                  : null,
              label: 'Confirm Reservation',
              icon: Icons.event_available_rounded,
            ),
            if (!controller.canConfirmBooking) ...[
              const SizedBox(height: 10),
              Text(
                controller.durationError ??
                    'Choose a date and a start time to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: controller.durationError == null
                      ? AppPalette.muted
                      : AppPalette.danger,
                  fontSize: 12.5,
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

  /// Opens the platform time picker. Dismissing it returns null, which leaves
  /// the current selection exactly as it was.
  ///
  /// The context is handed in by the builder because [GetView] is not a
  /// `State`, so it has no `context` of its own.
  Future<void> _pickCustomTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          controller.customTime.value ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Choose a custom time',
    );
    if (picked == null) {
      return;
    }
    controller.selectCustomTime(picked);
  }

  /// Reviews the reservation in the summary dialog and only then submits it.
  /// Cancelling changes nothing; a failed submit keeps the dialog open with the
  /// reason so the resident can retry without losing their date and time.
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
        return const AppConfirmResult.success();
      },
    );

    if (!confirmed) {
      return;
    }
    final reservation = controller.bookingSuccess.value;
    if (reservation != null) {
      // Replaces the reservation page so the back button from the success page
      // does not return to a form that has already been used.
      Get.offNamed(AppRoutes.bookingConfirmed, arguments: reservation);
    }
  }
}

class _FacilityReservationIntro extends StatelessWidget {
  const _FacilityReservationIntro({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFBFE8DF),
            child: Icon(
              Icons.event_available_rounded,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayFacilityName(facility.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2B2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  facility.location,
                  style: const TextStyle(
                    color: Color(0xFF52635F),
                    fontSize: 12,
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

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.dates,
    required this.selected,
    required this.onSelected,
  });

  /// The bookable window, generated from the current date by the controller.
  final List<String> dates;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates
            .map(
              (date) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('facility-date-$date'),
                  label: Text(date),
                  selected: date == selected,
                  onSelected: (_) => onSelected(date),
                  selectedColor: AppPalette.brandOnDark,
                  labelStyle: TextStyle(
                    color: date == selected
                        ? AppPalette.brand
                        : AppPalette.mutedStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hours in FacilityController.reservationDurations)
          ChoiceChip(
            key: Key('facility-duration-$hours'),
            label: Text(hours == 1 ? '1 hour' : '$hours hours'),
            selected: hours == selected,
            onSelected: (_) => onSelected(hours),
            selectedColor: AppPalette.brandOnDark,
            labelStyle: TextStyle(
              color: hours == selected
                  ? AppPalette.brand
                  : AppPalette.mutedStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

/// Shows the interval the resident has ended up with, so the end time is never
/// something they have to work out themselves.
class _ReservationInterval extends StatelessWidget {
  const _ReservationInterval({required this.range, required this.error});

  final AppTimeRange? range;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: hasError
            ? AppPalette.danger.withValues(alpha: 0.06)
            : AppPalette.brandTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppPalette.danger.withValues(alpha: 0.3)
              : AppPalette.brandSoft,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.error_outline_rounded : Icons.schedule_rounded,
            size: 18,
            color: hasError ? AppPalette.danger : AppPalette.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: hasError
                ? Text(
                    error!,
                    style: const TextStyle(
                      color: AppPalette.danger,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    range == null
                        ? 'Pick a start time to see your time range.'
                        : range!.label,
                    style: TextStyle(
                      color: range == null
                          ? AppPalette.muted
                          : AppPalette.brand,
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

  /// Custom time is offered after the facility's own slots and is always last,
  /// so the facility's schedule is not obscured.
  static const _customLabel = 'Custom time';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in facility.availableSlots)
          ChoiceChip(
            key: Key('facility-slot-$slot'),
            label: Text(slot),
            selected: slot == selected,
            onSelected: (_) => onSelected(slot),
            selectedColor: AppPalette.brandOnDark,
            labelStyle: TextStyle(
              color: slot == selected
                  ? AppPalette.brand
                  : AppPalette.mutedStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        // The icon and the label prefix set this apart from the facility's own
        // slots, and the label carries the chosen time once there is one.
        ChoiceChip(
          key: const Key('facility-slot-custom'),
          avatar: Icon(
            Icons.schedule_rounded,
            size: 17,
            color: customTimeSelected
                ? AppPalette.brand
                : AppPalette.mutedStrong,
          ),
          label: Text(
            customTimeSelected && selected != null ? selected! : _customLabel,
          ),
          selected: customTimeSelected,
          onSelected: (_) => onPickCustomTime(),
          selectedColor: AppPalette.brandOnDark,
          labelStyle: TextStyle(
            color: customTimeSelected
                ? AppPalette.brand
                : AppPalette.mutedStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
