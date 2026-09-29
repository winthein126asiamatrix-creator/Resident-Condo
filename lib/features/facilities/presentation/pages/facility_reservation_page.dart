import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/facility.dart';
import '../controllers/facility_controller.dart';

class FacilityReservationPage extends GetView<FacilityController> {
  const FacilityReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reserve facility')),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _FacilityReservationIntro(facility: facility),
            const SizedBox(height: 22),
            const Text(
              'Select a date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _DateSelector(
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
              onSelected: controller.selectSlot,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  controller.isBooking.value || facility.availableSlots.isEmpty
                  ? null
                  : _confirm,
              icon: controller.isBooking.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.event_available_rounded, size: 18),
              label: Text(
                controller.isBooking.value
                    ? 'Booking...'
                    : 'Confirm reservation',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: Color(0xFFC2410C)),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm reservation'),
        content: Text(
          'Reserve ${_displayName(controller.selectedFacility.value!.name)} for ${controller.selectedDate.value} at ${controller.selectedSlot.value}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reservation = await controller.bookSelectedSlot();
    if (reservation != null) {
      Get.offNamed(AppRoutes.bookingConfirmed, arguments: reservation);
    }
  }
}

String _displayName(String name) {
  if (name == 'Fitness Centre') {
    return 'Gym';
  }
  if (name == 'Rooftop BBQ') {
    return 'BBQ Area';
  }
  return name;
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
                  _displayName(facility.name),
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
  const _DateSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const dates = [
      'Sep 24, 2026',
      'Sep 25, 2026',
      'Sep 26, 2026',
      'Sep 27, 2026',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates
            .map(
              (date) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(date),
                  selected: date == selected,
                  onSelected: (_) => onSelected(date),
                  selectedColor: const Color(0xFFBFE8DF),
                  labelStyle: TextStyle(
                    color: date == selected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF52635F),
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
    required this.onSelected,
  });

  final Facility facility;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: facility.availableSlots
          .map(
            (slot) => ChoiceChip(
              label: Text(slot),
              selected: slot == selected,
              onSelected: (_) => onSelected(slot),
              selectedColor: const Color(0xFFBFE8DF),
              labelStyle: TextStyle(
                color: slot == selected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF52635F),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
          .toList(),
    );
  }
}
