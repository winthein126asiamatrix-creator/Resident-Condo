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
              'Select a time slot',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _SlotSelector(
              facility: facility,
              selected: controller.selectedSlot.value,
              customTimeSelected: controller.isCustomTimeSelected,
              customLabel: controller.customTime.value == null
                  ? null
                  : FacilityController.customSlotLabel(
                      controller.customTime.value!,
                    ),
              onSelected: controller.selectSlot,
              onPickCustomTime: () => _pickCustomTime(context),
            ),
            const SizedBox(height: 24),
            // The CTA is the only way a reservation is created: picking a date
            // or a time never submits anything.
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
              const Text(
                'Choose a date and a time to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.muted, fontSize: 12.5),
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
    final time = controller.selectedSlot.value;
    if (facility == null || time == null) {
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
        AppSummaryRow(label: 'Time', value: time),
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

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({
    required this.facility,
    required this.selected,
    required this.customTimeSelected,
    required this.customLabel,
    required this.onSelected,
    required this.onPickCustomTime,
  });

  final Facility facility;
  final String? selected;
  final bool customTimeSelected;

  /// The chosen custom time, shown in place of the generic label. Null until
  /// the resident picks one.
  final String? customLabel;
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
          label: Text(customTimeSelected ? customLabel! : _customLabel),
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
