import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_radius.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_text_styles.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/condo_service.dart';

import '../controllers/condo_service_controller.dart';

import '../widgets/service_widgets.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_form_field.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key});

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final CondoServiceController controller = Get.find<CondoServiceController>();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is int) {
      controller.loadServiceDetail(args);
    }
  }

  final TextEditingController _notesController = TextEditingController();

  List<String> _dates = <String>[];
  String? _selectedDate;
  int? _selectedSlotId;
  String _selectedSlotLabel = '';
  final Map<String, dynamic> _bookingValues = <String, dynamic>{};
  final Map<String, String> _fieldErrors = <String, String>{};
  String _error = '';
  String? _initializedServiceId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _initializeForService(CondoService service) {
    if (_initializedServiceId == service.id.toString()) return;
    _initializedServiceId = service.id.toString();
    _dates = service.availableDates
        .where((d) => d.slots.any((s) => s.isAvailable))
        .map((d) => d.date)
        .toList();
    _selectedDate = _dates.isNotEmpty ? _dates.first : null;
    _selectedSlotId = null;
    _selectedSlotLabel = '';
    _bookingValues.clear();
    _fieldErrors.clear();
    for (final field in service.bookingFields) {
      if (field.defaultValue != null) {
        _bookingValues[field.key] = field.defaultValue;
      }
    }
    _selectFirstAvailableSlot(service);
  }

  void _selectFirstAvailableSlot(CondoService service) {
    final date = _selectedDate;
    if (date == null) return;
    final availableDate = service.availableDates.firstWhereOrNull(
      (d) => d.date == date,
    );
    final slots =
        availableDate?.slots.where((s) => s.isAvailable).toList() ??
        const <ServiceTimeSlot>[];
    if (slots.isNotEmpty) {
      _selectedSlotId = slots.first.id;
      _selectedSlotLabel = '${slots.first.startTime} - ${slots.first.endTime}';
    } else {
      _selectedSlotId = null;
      _selectedSlotLabel = '';
    }
  }

  List<ServiceTimeSlot> _slotsFor(CondoService service, String? date) {
    if (date == null) return const <ServiceTimeSlot>[];
    final availableDate = service.availableDates.firstWhereOrNull(
      (d) => d.date == date,
    );
    return availableDate?.slots ?? const <ServiceTimeSlot>[];
  }

  String? _validateField(ServiceBookingField field) {
    final value = _bookingValues[field.key];
    if (field.required) {
      if (value == null) return 'Required';
      if (value is String && value.trim().isEmpty) return 'Required';
      if (value is List && value.isEmpty) return 'Required';
    }
    if (field.type == ServiceBookingFieldType.quantity && value != null) {
      final number = value is num ? value : num.tryParse('$value');
      if (number == null) return 'Enter a valid number';
      if (field.min != null && number < field.min!)
        return 'Minimum ${field.min}';
      if (field.max != null && number > field.max!)
        return 'Maximum ${field.max}';
    }
    return null;
  }

  bool _validateAll(CondoService service) {
    var valid = true;
    for (final field in service.bookingFields) {
      final error = _validateField(field);
      if (error != null) {
        _fieldErrors[field.key] = error;
        valid = false;
      } else {
        _fieldErrors.remove(field.key);
      }
    }
    if (_selectedDate == null || _selectedSlotId == null) {
      _error = 'Choose a preferred date and time slot.';
      valid = false;
    } else {
      _error = '';
    }
    return valid;
  }

  Future<void> _submit() async {
    _error = '';
    final service = controller.selectedService.value;
    if (service == null) return;
    if (!_validateAll(service)) {
      setState(() {});
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Confirm booking?',
      message: '${service.name} on $_selectedDate, $_selectedSlotLabel.',
      confirmLabel: 'Confirm booking',
    );
    if (!confirmed || !mounted) return;
    final request = await controller.bookService(
      service: service,
      date: _selectedDate!,
      slot: _selectedSlotLabel,
      slotId: _selectedSlotId,
      bookingDetails: Map<String, dynamic>.from(_bookingValues),
      notes: _notesController.text.trim(),
    );
    if (!mounted) return;
    if (request == null) {
      final message = controller.errorMessage.value ?? 'Booking failed.';
      vibrateNow();
      setState(() {
        _error = message;
      });
      showAppFeedback(
        context,
        title: 'Booking failed',
        message: message,
        isError: true,
      );
      return;
    }
    Get.offNamed(AppRoutes.serviceRequestDetail, arguments: request);
  }

  Widget _buildBookingField(CondoService service, ServiceBookingField field) {
    final tokens = AppThemeTokens.of(context);
    final errorText = _fieldErrors[field.key];
    switch (field.type) {
      case ServiceBookingFieldType.quantity:
        return AppTextField(
          fieldKey: Key('booking-${field.key}'),
          label: field.label,
          hint: field.min != null ? 'Min ${field.min}' : null,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _bookingValues[field.key] = int.tryParse(value) ?? value;
              _fieldErrors.remove(field.key);
            });
          },
        );
      case ServiceBookingFieldType.text:
        return AppTextField(
          fieldKey: Key('booking-${field.key}'),
          label: field.label,
          onChanged: (value) {
            setState(() {
              _bookingValues[field.key] = value;
              _fieldErrors.remove(field.key);
            });
          },
        );
      case ServiceBookingFieldType.singleSelect:
        return DropdownButtonFormField<String>(
          key: Key('booking-${field.key}'),
          decoration: InputDecoration(
            labelText: field.label,

            border: const OutlineInputBorder(),
          ),
          initialValue: _bookingValues[field.key] as String?,
          items: field.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _bookingValues[field.key] = value;
              _fieldErrors.remove(field.key);
            });
          },
        );
      case ServiceBookingFieldType.multiSelect:
        final selected =
            (_bookingValues[field.key] as List?)?.cast<String>() ?? <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label,
              style: TextStyle(
                color: tokens.mutedStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
            8.h.heightBox(),
            Wrap(
              spacing: 8,
              children: field.options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      final next = List<String>.from(selected);
                      if (value) {
                        next.add(option);
                      } else {
                        next.remove(option);
                      }
                      _bookingValues[field.key] = next;
                      _fieldErrors.remove(field.key);
                    });
                  },
                );
              }).toList(),
            ),
            if (errorText != null) ...[
              4.h.heightBox(),
              Text(
                errorText,
                style: TextStyle(color: AppPalette.danger, fontSize: 12.sp),
              ),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingDetail.value) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Book a service'),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      final service = controller.selectedService.value;
      if (service == null) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Book a service'),
          body: AppStateMessage(
            title: 'No service selected',
            message: 'Pick a service from the catalogue first.',
            icon: Icons.room_service_outlined,
            actionLabel: 'Back to services',
            onAction: () => Get.offNamed(AppRoutes.services),
          ),
        );
      }
      if (!service.isActive) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Book a service'),
          body: AppStateMessage(
            title: 'Service unavailable',
            message: 'This service is not available for booking.',
            icon: Icons.block_rounded,
            actionLabel: 'Back to services',
            onAction: () => Get.offNamed(AppRoutes.services),
          ),
        );
      }
      _initializeForService(service);
      final tokens = AppThemeTokens.of(context);
      final styles = AppTextStyles.of(context);
      final error = _error.isNotEmpty ? _error : controller.errorMessage.value;
      final slots = _slotsFor(service, _selectedDate);
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Book a service'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.pageBottom,
          ),
          children: [
            Text(
              'Choose a preferred date and time. The concierge team will confirm your booking.',
              style: styles.caption,
            ),
            16.h.heightBox(),
            _SelectedServiceCard(service: service),
            22.h.heightBox(),
            if (service.bookingFields.isNotEmpty) ...[
              AppSectionCard(
                title: 'Booking details',
                subtitle: 'Provide the details required for this service.',
                child: Column(
                  children: [
                    for (final field in service.bookingFields) ...[
                      _buildBookingField(service, field),
                      12.h.heightBox(),
                    ],
                  ],
                ),
              ),
              18.h.heightBox(),
            ],
            AppSectionCard(
              title: 'Schedule',
              subtitle: 'Choose a preferred date and time for the visit.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldHeading(
                    icon: Icons.calendar_today_rounded,
                    label: 'Preferred date',
                  ),
                  8.h.heightBox(),
                  if (_dates.isEmpty)
                    Text(
                      'No available dates',
                      style: TextStyle(color: tokens.muted),
                    )
                  else
                    _DateGrid(
                      dates: _dates,
                      selected: _selectedDate ?? '',
                      onSelected: (date) => setState(() {
                        _selectedDate = date;
                        _selectFirstAvailableSlot(service);
                        _error = '';
                      }),
                    ),
                  18.h.heightBox(),
                  _FieldHeading(
                    icon: Icons.schedule_rounded,
                    label: 'Time slot',
                  ),
                  8.h.heightBox(),
                  if (slots.isEmpty)
                    Text(
                      'No available slots',
                      style: TextStyle(color: tokens.muted),
                    )
                  else
                    Column(
                      children: [
                        for (final slot in slots)
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: _SelectionTile(
                              label: '${slot.startTime} - ${slot.endTime}',
                              icon: Icons.schedule_rounded,
                              selected: slot.id == _selectedSlotId,
                              enabled: slot.isAvailable,
                              onTap: slot.isAvailable
                                  ? () => setState(() {
                                      _selectedSlotId = slot.id;
                                      _selectedSlotLabel =
                                          '${slot.startTime} - ${slot.endTime}';
                                      _error = '';
                                    })
                                  : () {},
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            18.h.heightBox(),
            AppSectionCard(
              title: 'Additional details',
              subtitle: 'Share access instructions or anything else we need.',
              child: AppTextField(
                fieldKey: Key('service-notes-field'),
                label: 'Notes for the team',
                controller: _notesController,
                hint: 'Anything the team should know.',
                maxLines: 3,
              ),
            ),
            18.h.heightBox(),
            AppCard(
              color: AppPalette.warning.withValues(
                alpha: tokens.isDark ? 0.16 : 0.08,
              ),
              borderColor: AppPalette.warning.withValues(
                alpha: tokens.isDark ? 0.35 : 0.22,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppPalette.warning,
                    size: 20,
                  ),
                  10.w.widthBox(),
                  Expanded(
                    child: Text(
                      'The service fee is billed as its own line on your next '
                      'statement. It is never added to the monthly condo fee.',
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 11.5.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            22.h.heightBox(),
            AppSectionCard(
              title: 'Booking summary',
              child: Column(
                children: [
                  AppLabelValueRow(label: 'Service', value: service.name),
                  AppLabelValueRow(label: 'Date', value: _selectedDate ?? ''),
                  AppLabelValueRow(
                    label: 'Time slot',
                    value: _selectedSlotLabel,
                  ),
                  AppLabelValueRow(
                    label: 'Service fee',
                    value:
                        '${AppFormatters.currency(service.price)} ${service.unit}',
                    emphasize: true,
                  ),
                ],
              ),
            ),
            18.h.heightBox(),
            FilledButton.icon(
              key: Key('confirm-service-booking'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              icon: controller.isSubmitting.value
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onBrand,
                      ),
                    )
                  : Icon(Icons.check_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Booking...'
                    : 'Confirm booking',
              ),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(AppSpacing.buttonHeight),
              ),
            ),
            if (error != null && error.isNotEmpty) ...[
              12.h.heightBox(),
              _InlineError(message: error),
            ],
          ],
        ),
      );
    });
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service});

  final CondoService service;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final styles = AppTextStyles.of(context);
    return AppCard(
      color: tokens.brandTint,
      borderColor: tokens.brandBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(
                icon: serviceIcon(service.category),
                color: tokens.brand,
                size: 46,
              ),
              12.w.widthBox(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.cardTitle,
                    ),
                    4.h.heightBox(),
                    Text(
                      '${service.category.label} \u00B7 ${service.provider}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.muted, fontSize: 11.5.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          10.h.heightBox(),
          Text(
            service.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.5.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHeading extends StatelessWidget {
  const _FieldHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: tokens.muted),
        6.w.widthBox(),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateGrid extends StatelessWidget {
  const _DateGrid({
    required this.dates,
    required this.selected,
    required this.onSelected,
  });

  final List<String> dates;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final date in dates)
              SizedBox(
                width: itemWidth,
                child: _SelectionTile(
                  label: date,
                  icon: Icons.calendar_today_rounded,
                  selected: date == selected,
                  onTap: () => onSelected(date),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 54,
        decoration: BoxDecoration(
          color: selected ? tokens.brandTint : tokens.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? tokens.brandBorder : tokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? tokens.brand : tokens.muted,
                  ),
                  6.w.widthBox(),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? tokens.brand : tokens.mutedStrong,
                        fontSize: 12.5.sp,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  6.w.widthBox(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? tokens.brand : Colors.transparent,
                      border: Border.all(
                        color: selected ? tokens.brand : tokens.border,
                        width: 1.4,
                      ),
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: selected ? 1 : 0,
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: tokens.onBrand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: AppPalette.danger),
          8.w.widthBox(),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppPalette.danger,
                fontSize: 12.sp,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
