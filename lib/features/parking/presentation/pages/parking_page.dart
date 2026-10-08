import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/parking.dart';
import '../controllers/parking_controller.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/app_primary_action.dart';

class ParkingPage extends GetView<ParkingController> {
  const ParkingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Parking',
        actions: [
          IconButton(
            onPressed: controller.loadParking,
            tooltip: 'Refresh parking',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.spaces.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.spaces.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load parking',
            message: controller.errorMessage.value!,
            icon: Icons.directions_car_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadParking,
          );
        }
        final space = controller.mySpace.value;
        if (space == null) {
          return AppStateMessage(
            title: 'No parking space',
            message: 'No parking space is assigned to your unit.',
            icon: Icons.local_parking_outlined,
            actionLabel: 'Refresh',
            onAction: controller.loadParking,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadParking,
          child: ListView(
            key: const Key('parking-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              32,
            ),
            children: [
              _MySpaceCard(controller: controller, space: space),
              const SizedBox(height: 16),
              _QuickActions(controller: controller),
              const SizedBox(height: 20),
              AppSectionHeader(
                title: 'Building spaces',
                count: controller.spaces.length,
              ),
              const SizedBox(height: 10),
              for (final item in controller.spaces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SpaceTile(space: item, isMine: item.id == space.id),
                ),
              const SizedBox(height: 14),
              AppSectionHeader(
                title: 'Access log',
                count: controller.events.length,
              ),
              const SizedBox(height: 10),
              for (final event in controller.events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          event.type == ParkingEventType.entry
                              ? Icons.south_rounded
                              : Icons.north_rounded,
                          size: 18,
                          color: event.type == ParkingEventType.entry
                              ? AppPalette.success
                              : AppPalette.danger,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${event.type.label} ? ${event.slot}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Flexible so a long timestamp cannot overflow the card.
                        Flexible(
                          child: Text(
                            event.timestamp,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              AppSectionHeader(
                title: 'Guest parking',
                count: controller.activeGuestRequests,
              ),
              const SizedBox(height: 10),
              if (controller.guestRequests.isEmpty)
                Text(
                  'No guest parking requests yet.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                )
              else
                for (final request in controller.guestRequests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GuestRequestCard(
                      controller: controller,
                      request: request,
                    ),
                  ),
            ],
          ),
        );
      }),
    );
  }
}

class _MySpaceCard extends StatelessWidget {
  const _MySpaceCard({required this.controller, required this.space});
  final ParkingController controller;
  final ParkingSpace space;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppHeroPanel(
      icon: Icons.directions_car_filled_rounded,
      title: 'Slot ${space.slot}',
      subtitle: '${space.level} · ${space.type.label}',
      footnote:
          'Monthly parking fee '
          '${AppFormatters.currency(space.monthlyFee)} · billed separately',
      trailing: AppStatusPill(
        label: space.status.label,
        color: space.status == ParkingStatus.occupied
            ? AppPalette.success
            : AppPalette.warning,
      ),
      leading: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  space.vehicle,
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  space.licensePlate,
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _editVehicle(context),
            style: TextButton.styleFrom(foregroundColor: tokens.brandOnDark),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _editVehicle(BuildContext context) async {
    final result = await showModalBottomSheet<({String vehicle, String plate})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _VehicleSheet(space: space),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Update vehicle?',
      message:
          'Slot ${space.slot} will be linked to ${result.plate} '
          '(${result.vehicle}).',
      confirmLabel: 'Save vehicle',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.updateVehicle(
      result.vehicle,
      result.plate,
    );
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to update' : 'Vehicle updated',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Slot ${updated.slot} is now linked to ${updated.licensePlate}.',
      isError: updated == null,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});
  final ParkingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            onPressed: () => _requestGuest(context),
            label: 'Guest parking',
            icon: Icons.local_taxi_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppOutlinedButton(
            onPressed: controller.loadParking,
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            foregroundColor: tokens.mutedStrong,
          ),
        ),
      ],
    );
  }

  Future<void> _requestGuest(BuildContext context) async {
    final details =
        await showDialog<({String name, String vehicle, String plate})>(
          context: context,
          builder: (dialogContext) => const _GuestParkingDialog(),
        );
    if (details == null || !context.mounted) {
      return;
    }
    final created = await controller.requestGuestParking(
      guestName: details.name,
      vehicle: details.vehicle,
      plate: details.plate,
      date: 'Sep 26, 2026',
      window: '10:00 AM – 6:00 PM',
    );
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: created == null ? 'Unable to request' : 'Guest parking requested',
      message: created == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : '${created.licensePlate} on ${created.date} is pending review.',
      isError: created == null,
    );
  }
}

class _GuestParkingDialog extends StatefulWidget {
  const _GuestParkingDialog();

  @override
  State<_GuestParkingDialog> createState() => _GuestParkingDialogState();
}

class _GuestParkingDialogState extends State<_GuestParkingDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _vehicle = TextEditingController();
  final TextEditingController _plate = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Request guest parking'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              fieldKey: const Key('guest-name-field'),
              label: 'Guest name',
              controller: _name,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(label: 'Vehicle model', controller: _vehicle),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              fieldKey: const Key('guest-plate-field'),
              label: 'License plate',
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                style: const TextStyle(color: AppPalette.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Request')),
      ],
    );
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Guest name is required.');
      return;
    }
    if (_plate.text.trim().length < 3) {
      setState(() => _error = 'Enter the guest vehicle plate.');
      return;
    }
    Navigator.pop(context, (
      name: _name.text.trim(),
      vehicle: _vehicle.text.trim(),
      plate: _plate.text.trim(),
    ));
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space, required this.isMine});
  final ParkingSpace space;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = switch (space.status) {
      ParkingStatus.occupied => AppPalette.success,
      ParkingStatus.available => tokens.brand,
      ParkingStatus.reserved => AppPalette.warning,
      ParkingStatus.blocked => AppPalette.danger,
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppIconTile(
            icon: Icons.local_parking_rounded,
            color: color,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Flexible so a long slot code cannot push the badge out.
                    Flexible(
                      child: Text(
                        space.slot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 8),
                      AppStatusPill(
                        label: 'Yours',
                        color: tokens.brand,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  space.licensePlate.isEmpty
                      ? '${space.level} ? ${space.assignedTo}'
                      : '${space.level} ? ${space.licensePlate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          AppStatusPill(label: space.status.label, color: color, dense: true),
        ],
      ),
    );
  }
}

class _GuestRequestCard extends StatelessWidget {
  const _GuestRequestCard({required this.controller, required this.request});
  final ParkingController controller;
  final GuestParkingRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final cancelled = request.status == 'Cancelled';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.guestName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              AppStatusPill(
                label: request.status,
                color: cancelled ? AppPalette.danger : AppPalette.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.licensePlate} · ${request.date} · ${request.window}',
            style: TextStyle(color: tokens.mutedStrong, fontSize: 12),
          ),
          if (request.vehicle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              request.vehicle,
              style: TextStyle(color: tokens.faint, fontSize: 11),
            ),
          ],
          if (!cancelled) ...[
            const SizedBox(height: 12),
            AppOutlinedButton(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => _cancel(context),
              label: 'Cancel request',
              icon: Icons.cancel_outlined,
              foregroundColor: AppPalette.danger,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel guest parking?',
      message:
          'The bay reserved for ${request.licensePlate} on ${request.date} will '
          'be released.',
      confirmLabel: 'Cancel request',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.cancelGuestParking(request);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to cancel' : 'Request cancelled',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'The guest bay has been released.',
      isError: updated == null,
    );
  }
}

class _VehicleSheet extends StatefulWidget {
  const _VehicleSheet({required this.space});
  final ParkingSpace space;

  @override
  State<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends State<_VehicleSheet> {
  late final TextEditingController _vehicle;
  late final TextEditingController _plate;

  @override
  void initState() {
    super.initState();
    _vehicle = TextEditingController(text: widget.space.vehicle);
    _plate = TextEditingController(text: widget.space.licensePlate);
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update vehicle',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Slot ${widget.space.slot}',
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          AppTextField(
            fieldKey: const Key('vehicle-model-field'),
            label: 'Vehicle model',
            controller: _vehicle,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            fieldKey: const Key('vehicle-plate-field'),
            label: 'License plate',
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 18),
          AppPrimaryAction(
            onPressed: () => Navigator.pop(context, (
              vehicle: _vehicle.text,
              plate: _plate.text,
            )),
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}
