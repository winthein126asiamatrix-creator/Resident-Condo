import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
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

  static final _startOptions = <DateTime>[
    DateTime(2026, 11, 1),
    DateTime(2026, 12, 1),
    DateTime(2027, 1, 1),
  ];

  static final _endOptions = <DateTime>[
    DateTime(2027, 10, 31),
    DateTime(2027, 11, 30),
    DateTime(2027, 12, 31),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) {
      return;
    }
    _seeded = true;
    final lease = controller.selectedLease.value;
    _start = _startOptions.first;
    _end = _endOptions.first;
    if (lease != null) {
      _rentController.text = (lease.monthlyRent * 1.03).round().toString();
    }
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
              'Proposed start date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _DateChoices(
              options: _startOptions,
              selected: _start,
              onSelected: (value) => setState(() {
                _start = value;
                _error = '';
              }),
            ),
            const SizedBox(height: 20),
            const Text(
              'Proposed end date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _DateChoices(
              options: _endOptions,
              selected: _end,
              onSelected: (value) => setState(() {
                _end = value;
                _error = '';
              }),
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
          '${AppDates.format(_start)} to ${AppDates.format(_end)}.',
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
}

class _DateChoices extends StatelessWidget {
  const _DateChoices({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final List<DateTime> options;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text(AppDates.format(option)),
              selected: option == selected,
              onSelected: (_) => onSelected(option),
              selectedColor: AppPalette.brandSoft,
              labelStyle: TextStyle(
                color: option == selected
                    ? AppPalette.brand
                    : AppPalette.mutedStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
          .toList(),
    );
  }
}
