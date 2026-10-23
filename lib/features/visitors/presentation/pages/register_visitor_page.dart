import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/text_input_formatters.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../domain/entities/visitor.dart';

import '../controllers/visitor_controller.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/widgets/app_form_field.dart';

import '../../../../core/widgets/app_primary_action.dart';

import '../../../../core/theme/app_radius.dart';

import '../../../../core/utils/app_dates.dart';

import '../../../../core/utils/app_times.dart';

class RegisterVisitorPage extends StatefulWidget {
  const RegisterVisitorPage({super.key});

  @override
  State<RegisterVisitorPage> createState() => _RegisterVisitorPageState();
}

class _RegisterVisitorPageState extends State<RegisterVisitorPage> {
  final VisitorController controller = Get.find<VisitorController>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  VisitorRelation _relation = VisitorRelation.family;
  String _date = '';
  String _arrival = '';
  String _error = '';

  static const _dateWindowDays = 4;
  static const _visitHours = 2;
  static const _arrivalSlotCount = 6;

  static const _futureSlots = <String>[
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _date = _visitDates.first.value;
    _arrival = _arrivalSlots.isEmpty ? '' : _arrivalSlots.first;
  }

  List<({String value, String relative, String day, String month})>
  get _visitDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(_dateWindowDays, (index) {
      final date = DateTime(today.year, today.month, today.day + index);
      return (
        value: AppDates.format(date),
        relative: switch (index) {
          0 => 'today'.tr,
          1 => 'tomorrow'.tr,
          _ => AppDates.weekday(date),
        },
        day: date.day.toString().padLeft(2, '0'),
        month: AppDates.formatShort(date).split(' ').last,
      );
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date == AppDates.format(DateTime(now.year, now.month, now.day));
  }

  List<String> get _arrivalSlots {
    if (!_isToday) {
      return _futureSlots;
    }
    final now = DateTime.now();
    final first = AppTimes.nextFullHour(now);
    if (first.day != now.day) {
      return [];
    }
    final count = _arrivalSlotCount.clamp(0, 24 - first.hour);
    return [
      for (var index = 0; index < count; index++)
        AppTimes.format(TimeOfDay(hour: first.hour + index, minute: 0)),
    ];
  }

  bool _canArriveAt(String label) {
    if (!_isToday) {
      return true;
    }
    final time = AppTimes.parse(label);
    if (time == null) {
      return false;
    }
    return AppTimes.isAfter(time, TimeOfDay.now());
  }

  AppTimeRange get _visitWindow =>
      AppTimeRange.fromLabel(_arrival, _visitHours) ??
      AppTimeRange(
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 12, minute: 0),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'registerVisitor'.tr,
        subtitle: 'createVisitorAccessCode'.tr,
      ),
      body: Obx(
        () => ListView(
          key: const Key('register-visitor-scroll'),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            AppCard(
              color: tokens.brandTint,
              borderColor: tokens.brandSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.vpn_key_outlined, color: tokens.brand),
                  10.w.widthBox(),
                  Expanded(
                    child: Text(
                      'An alphanumeric access code is generated automatically '
                      'when you register. Share the code with your visitor - no '
                      'QR pass is used.',
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 12.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            20.h.heightBox(),
            _SectionTitle(
              icon: Icons.person_outline_rounded,
              title: 'visitorDetails'.tr,
            ),
            10.h.heightBox(),
            AppCard(
              showShadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    fieldKey: const Key('visitor-name-field'),
                    label: 'visitorName'.tr,
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    hint: 'visitorNameHint'.tr,
                    icon: Icons.person_outline_rounded,
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  AppTextField(
                    fieldKey: const Key('visitor-phone-field'),
                    label: 'visitorPhone'.tr,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    ],
                    hint: 'visitorPhoneHint'.tr,
                    icon: Icons.phone_outlined,
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  _RelationSelector(
                    relation: _relation,
                    onChanged: (relation) {
                      setState(() => _relation = relation);
                    },
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  AppTextField(
                    label: 'visitorPurpose'.tr,
                    controller: _notesController,
                    hint: 'visitorPurposeHint'.tr,
                    icon: Icons.notes_rounded,
                  ),
                ],
              ),
            ),
            20.h.heightBox(),
            _SectionTitle(icon: Icons.event_rounded, title: 'visitSchedule'.tr),
            10.h.heightBox(),
            AppCard(
              showShadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('visitDate'.tr),
                  8.h.heightBox(),
                  _VisitDatePicker(
                    dates: _visitDates,
                    selected: _date,
                    onSelected: _selectDate,
                  ),
                  AppSpacing.fieldGap.heightBox(),
                  _ArrivalTimeSelector(
                    arrival: _arrival,
                    slots: _arrivalSlots,
                    isToday: _isToday,
                    canArriveAt: _canArriveAt,
                    onSlotSelected: (slot) {
                      setState(() {
                        _arrival = slot;
                        _arrivalIsCustom = false;
                        _error = '';
                      });
                    },
                    onCustomPressed: () => _pickCustomArrival(context),
                    arrivalIsCustom: _arrivalIsCustom,
                  ),
                  10.h.heightBox(),
                  _VisitWindow(range: _visitWindow),
                ],
              ),
            ),
            20.h.heightBox(),
            _SectionTitle(
              icon: Icons.directions_car_outlined,
              title: 'additionalDetails'.tr,
            ),
            10.h.heightBox(),
            AppCard(
              showShadow: true,
              child: AppTextField(
                label: 'vehiclePlate'.tr,
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                hint: 'vehiclePlateHint'.tr,
                icon: Icons.directions_car_outlined,
              ),
            ),
            24.h.heightBox(),
            AppPrimaryAction(
              key: const Key('submit-visitor'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              isLoading: controller.isSubmitting.value,
              label: controller.isSubmitting.value
                  ? 'registering'.tr
                  : 'registerVisitorBtn'.tr,
              icon: Icons.person_add_alt_1_rounded,
            ),
            if (_error.isNotEmpty) ...[
              10.h.heightBox(),
              Text(_error, style: TextStyle(color: AppPalette.danger)),
            ],
            if (controller.errorMessage.value != null) ...[
              10.h.heightBox(),
              Text(
                controller.errorMessage.value!,
                style: TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _arrivalIsCustom = false;

  void _selectDate(String date) {
    setState(() {
      _date = date;
      _error = '';
      if (_canArriveAt(_arrival)) {
        return;
      }
      _arrival = _arrivalSlots.isEmpty ? '' : _arrivalSlots.first;
      _arrivalIsCustom = false;
    });
  }

  Future<void> _pickCustomArrival(BuildContext context) async {
    final now = TimeOfDay.now();
    final current = AppTimes.parse(_arrival);
    final opening = _canArriveAt(_arrival)
        ? current
        : (_isToday
              ? TimeOfDay(hour: now.hour + 1, minute: 0)
              : TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ?? TimeOfDay(hour: 10, minute: 0),
      helpText: 'chooseArrivalTime'.tr,
    );
    if (picked == null || !mounted) {
      return;
    }
    if (!_canArriveAt(AppTimes.format(picked))) {
      setState(
        () => _error = 'arrivalTimePastError'.tr,
      );
      return;
    }
    setState(() {
      _arrival = AppTimes.format(picked);
      _arrivalIsCustom = true;
      _error = '';
    });
  }

  Future<void> _submit() async {
    _error = '';
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'visitorNameRequired'.tr);
      return;
    }
    if (_phoneController.text.trim().length < 6) {
      setState(() => _error = 'visitorPhoneRequired'.tr);
      return;
    }
    if (_date.isEmpty) {
      setState(() => _error = 'visitDateRequired'.tr);
      return;
    }
    if (_arrival.isEmpty) {
      setState(() => _error = 'arrivalTimeRequired'.tr);
      return;
    }
    if (!_canArriveAt(_arrival)) {
      setState(
        () => _error = 'arrivalTimePastError'.tr,
      );
      return;
    }
    final window = _visitWindow;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'confirmRegister'.tr,
      message: 'confirmRegisterMessage'.tr
          .replaceAll('{name}', name)
          .replaceAll('{date}', _date)
          .replaceAll('{window}', window.label),
      confirmLabel: 'confirmRegisterBtn'.tr,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final visitor = await controller.registerVisitor(
      name: name,
      phone: _phoneController.text,
      relation: _relation,
      purpose: _notesController.text.trim().isEmpty
          ? _relation.label
          : _notesController.text.trim(),
      date: _date,
      arrivalWindow: window.label,
      vehiclePlate: _plateController.text.trim().isEmpty
          ? null
          : _plateController.text.trim(),
      notes: _notesController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (visitor == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'registrationFailed'.tr;
      });
      return;
    }
    Get.offNamed(AppRoutes.visitorPass, arguments: visitor);
  }
}

class _RelationSelector extends StatelessWidget {
  const _RelationSelector({
    required this.relation,
    required this.onChanged,
  });

  final VisitorRelation relation;
  final ValueChanged<VisitorRelation> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('visitorRelation'.tr),
        8.h.heightBox(),
        InkWell(
          onTap: () => _showRelationBottomSheet(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    relation.icon,
                    size: 20,
                    color: tokens.brand,
                  ),
                ),
                12.w.widthBox(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'visitorRelation'.tr,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      2.h.heightBox(),
                      Text(
                        relation.label,
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: tokens.mutedStrong,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showRelationBottomSheet(BuildContext context) async {
    await showModalBottomSheet<VisitorRelation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RelationBottomSheet(
        currentRelation: relation,
        onSelected: onChanged,
      ),
    );
  }
}

class _RelationBottomSheet extends StatelessWidget {
  const _RelationBottomSheet({
    required this.currentRelation,
    required this.onSelected,
  });

  final VisitorRelation currentRelation;
  final ValueChanged<VisitorRelation> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          16.h.heightBox(),
          Row(
            children: [
              Icon(Icons.family_restroom_rounded, color: tokens.brand, size: 22),
              10.w.widthBox(),
              Text(
                'visitorRelation'.tr,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          16.h.heightBox(),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: VisitorRelation.values.map((relation) {
              final isSelected = relation == currentRelation;
              return _RelationCard(
                relation: relation,
                isSelected: isSelected,
                onTap: () {
                  vibrateNow();
                  onSelected(relation);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          8.h.heightBox(),
        ],
      ),
    );
  }
}

class _RelationCard extends StatelessWidget {
  const _RelationCard({
    required this.relation,
    required this.isSelected,
    required this.onTap,
  });

  final VisitorRelation relation;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: relation.label,
      child: Material(
        color: isSelected ? tokens.brandTint : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isSelected ? tokens.brand : tokens.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.brand : tokens.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    relation.icon,
                    size: 22,
                    color: isSelected ? tokens.onBrand : tokens.brand,
                  ),
                ),
                8.h.heightBox(),
                Flexible(
                  child: Text(
                    relation.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? tokens.brand : tokens.ink,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
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

class _ArrivalTimeSelector extends StatelessWidget {
  const _ArrivalTimeSelector({
    required this.arrival,
    required this.slots,
    required this.isToday,
    required this.canArriveAt,
    required this.onSlotSelected,
    required this.onCustomPressed,
    required this.arrivalIsCustom,
  });

  final String arrival;
  final List<String> slots;
  final bool isToday;
  final bool Function(String) canArriveAt;
  final ValueChanged<String> onSlotSelected;
  final VoidCallback onCustomPressed;
  final bool arrivalIsCustom;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    if (slots.isEmpty) {
      return _NoSlotsToday();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('arrivalTime'.tr),
        8.h.heightBox(),
        InkWell(
          onTap: onCustomPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: tokens.brand,
                  ),
                ),
                12.w.widthBox(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'arrivalTime'.tr,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      2.h.heightBox(),
                      Text(
                        arrival.isEmpty ? 'arrivalTimeHint'.tr : arrival,
                        style: TextStyle(
                          color: arrival.isEmpty ? tokens.mutedStrong : tokens.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: tokens.mutedStrong,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
        // 10.h.heightBox(),
        // Wrap(
        //   spacing: 8,
        //   runSpacing: 8,
        //   children: [
        //     for (final slot in slots)
        //       _TimeSlotChip(
        //         label: slot,
        //         selected: slot == arrival && !arrivalIsCustom,
        //         enabled: canArriveAt(slot),
        //         onTap: () => onSlotSelected(slot),
        //       ),
        //     _TimeSlotChip(
        //       label: arrivalIsCustom ? arrival : 'customTime'.tr,
        //       selected: arrivalIsCustom,
        //       enabled: true,
        //       isCustom: true,
        //       onTap: onCustomPressed,
        //     ),
        //   ],
        // ),
      ],
    );
  }
}

class _TimeSlotChip extends StatelessWidget {
  const _TimeSlotChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.isCustom = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = selected ? tokens.brand : (enabled ? tokens.mutedStrong : tokens.faint);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Material(
        color: selected ? tokens.brandSoft : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? tokens.brand : (enabled ? tokens.border : tokens.faint),
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCustom) ...[
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: selected ? tokens.brand : tokens.mutedStrong,
                  ),
                  6.w.widthBox(),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 12.5.sp,
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

class _VisitDatePicker extends StatelessWidget {
  const _VisitDatePicker({
    required this.dates,
    required this.selected,
    required this.onSelected,
  });

  final List<({String value, String relative, String day, String month})> dates;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < dates.length; index++) ...[
          Expanded(
            child: _VisitDateCard(
              key: Key('visit-date-${dates[index].value}'),
              date: dates[index],
              selected: dates[index].value == selected,
              onTap: () {
                vibrateNow();
                onSelected(dates[index].value);
              },
            ),
          ),
          if (index < dates.length - 1) 8.w.widthBox(),
        ],
      ],
    );
  }
}

class _VisitDateCard extends StatelessWidget {
  const _VisitDateCard({
    required this.date,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ({String value, String relative, String day, String month}) date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.relative}, ${date.day} ${date.month}',
      child: Material(
        color: selected ? tokens.brand : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? tokens.brand : tokens.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date.relative,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? tokens.brandOnDark : tokens.muted,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                4.h.heightBox(),
                Text(
                  date.day,
                  style: TextStyle(
                    color: selected ? tokens.onBrand : tokens.ink,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                1.h.heightBox(),
                Text(
                  date.month,
                  style: TextStyle(
                    color: selected ? tokens.brandOnDark : tokens.muted,
                    fontSize: 10.5.sp,
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

class _NoSlotsToday extends StatelessWidget {
  const _NoSlotsToday();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: AppPalette.warning),
          9.w.widthBox(),
          Expanded(
            child: Text(
              'noSlotsToday'.tr,
              style: TextStyle(
                color: tokens.mutedStrong,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitWindow extends StatelessWidget {
  const _VisitWindow({required this.range});

  final AppTimeRange range;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: tokens.brandSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse_rounded, size: 18, color: tokens.brand),
          10.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'visitTime'.tr,
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                2.h.heightBox(),
                Text(
                  range.label,
                  style: TextStyle(
                    color: tokens.brand,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'visitDuration'.tr,
            style: TextStyle(
              color: tokens.mutedStrong,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.brand),
        8.w.widthBox(),
        Text(
          title,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
    );
  }
}