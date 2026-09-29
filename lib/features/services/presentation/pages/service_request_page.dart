import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../controllers/condo_service_controller.dart';
import '../widgets/service_widgets.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final CondoServiceController controller = Get.find<CondoServiceController>();
  final TextEditingController _notesController = TextEditingController();

  String _date = 'Sep 27, 2026';
  String _slot = '9:00 AM – 11:00 AM';
  String _error = '';

  static const _dates = [
    'Sep 26, 2026',
    'Sep 27, 2026',
    'Sep 28, 2026',
    'Sep 29, 2026',
  ];
  static const _slots = [
    '9:00 AM – 11:00 AM',
    '1:00 PM – 3:00 PM',
    '4:00 PM – 6:00 PM',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = controller.selectedService.value;
      if (service == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Book a service')),
          body: AppStateMessage(
            title: 'No service selected',
            message: 'Pick a service from the catalogue first.',
            icon: Icons.room_service_outlined,
            actionLabel: 'Back to services',
            onAction: () => Get.offNamed(AppRoutes.services),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Book a service')),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            AppCard(
              child: Row(
                children: [
                  AppIconTile(
                    icon: serviceIcon(service.category),
                    color: AppPalette.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.provider,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppFormatters.currency(service.price)} ${service.unit}',
                          style: const TextStyle(
                            color: AppPalette.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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
              'Preferred date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dates
                  .map(
                    (date) => ChoiceChip(
                      label: Text(date),
                      selected: date == _date,
                      onSelected: (_) => setState(() {
                        _date = date;
                        _error = '';
                      }),
                      selectedColor: AppPalette.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Time slot',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(slot),
                      selected: slot == _slot,
                      onSelected: (_) => setState(() => _slot = slot),
                      selectedColor: AppPalette.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notes for the team',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('service-notes-field'),
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Anything the team should know…',
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              color: AppPalette.amberSoft,
              borderColor: const Color(0xFFF2E0B8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppPalette.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'The service fee is billed as its own line on your next '
                      'statement. It is never added to the monthly condo fee.',
                      style: TextStyle(
                        color: AppPalette.mutedStrong,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('confirm-service-booking'),
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
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Booking...'
                    : 'Confirm booking',
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
    final service = controller.selectedService.value;
    if (service == null) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Confirm booking?',
      message:
          '${service.name} on $_date, $_slot for '
          '${AppFormatters.currency(service.price)} ${service.unit}.',
      confirmLabel: 'Confirm booking',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final request = await controller.bookService(
      service: service,
      date: _date,
      slot: _slot,
      notes: _notesController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (request == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'Booking failed.';
      });
      return;
    }
    Get.offNamed(AppRoutes.serviceRequestDetail, arguments: request);
  }
}
