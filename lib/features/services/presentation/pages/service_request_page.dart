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
  final TextEditingController _notesController = TextEditingController();

  String _date = 'Sep 27, 2026';
  String _slot = '9:00 AM â€“ 11:00 AM';
  String _error = '';

  static const _dates = [
    'Sep 26, 2026',
    'Sep 27, 2026',
    'Sep 28, 2026',
    'Sep 29, 2026',
  ];
  static const _slots = [
    '9:00 AM â€“ 11:00 AM',
    '1:00 PM â€“ 3:00 PM',
    '4:00 PM â€“ 6:00 PM',
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
      final tokens = AppThemeTokens.of(context);
      final styles = AppTextStyles.of(context);
      final error = _error.isNotEmpty ? _error : controller.errorMessage.value;
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
                  _DateGrid(
                    dates: _dates,
                    selected: _date,
                    onSelected: (date) => setState(() {
                      _date = date;
                      _error = '';
                    }),
                  ),
                  18.h.heightBox(),
                  _FieldHeading(
                    icon: Icons.schedule_rounded,
                    label: 'Time slot',
                  ),
                  8.h.heightBox(),
                  _SlotList(
                    slots: _slots,
                    selected: _slot,
                    onSelected: (slot) => setState(() {
                      _slot = slot;
                      _error = '';
                    }),
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
                  AppLabelValueRow(label: 'Date', value: _date),
                  AppLabelValueRow(label: 'Time slot', value: _slot),
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
              8.w.widthBox(),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: tokens.onBrand,
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
          12.h.heightBox(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: tokens.faint),
              5.w.widthBox(),
              Expanded(
                child: Text(
                  'Needs ${service.leadTimeDays} day notice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                ),
              ),
              8.w.widthBox(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.currency(service.price),
                    style: TextStyle(
                      color: tokens.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                    ),
                  ),
                  2.h.heightBox(),
                  Text(
                    service.unit,
                    style: TextStyle(color: tokens.muted, fontSize: 10.5.sp),
                  ),
                ],
              ),
            ],
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

class _SlotList extends StatelessWidget {
  const _SlotList({
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<String> slots;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < slots.length; index++) ...[
          _SelectionTile(
            label: slots[index],
            icon: Icons.schedule_rounded,
            selected: slots[index] == selected,
            onTap: () => onSelected(slots[index]),
          ),
          if (index != slots.length - 1) 10.h.heightBox(),
        ],
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

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
            onTap: () {
              vibrateNow();
              onTap();
            },
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
