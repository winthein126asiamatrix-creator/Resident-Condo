import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
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

  /// Today plus the next three days, generated on open so the list never goes
  /// stale against the real calendar.
  static const _dateWindowDays = 4;

  /// A visit always runs two hours from the arrival time.
  static const _visitHours = 2;

  /// How many hourly slots are offered for a visit today.
  static const _arrivalSlotCount = 6;

  /// The concierge day, offered for any visit that is not today. A future date is
  /// not held to the clock, so the full set is available.
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

  /// The selectable visit dates, each with the label a resident would use.
  List<({String value, String relative, String day, String month})>
  get _visitDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(_dateWindowDays, (index) {
      final date = DateTime(today.year, today.month, today.day + index);
      return (
        value: AppDates.format(date),
        relative: switch (index) {
          0 => 'Today',
          1 => 'Tomorrow',
          _ => AppDates.weekday(date),
        },
        day: date.day.toString().padLeft(2, '0'),
        month: AppDates.formatShort(date).split(' ').last,
      );
    });
  }

  /// True when the visit is for today, where the clock decides what is still
  /// bookable.
  bool get _isToday {
    final now = DateTime.now();
    return _date == AppDates.format(DateTime(now.year, now.month, now.day));
  }

  /// The arrival slots to offer.
  ///
  /// Today offers the next six full hours, so nothing that has already gone can
  /// be chosen. Any other date offers the concierge day, because the clock says
  /// nothing about a visit that has not happened yet. An empty list means the day
  /// is over and the resident needs a later date.
  List<String> get _arrivalSlots {
    if (!_isToday) {
      return _futureSlots;
    }
    final now = DateTime.now();
    final first = AppTimes.nextFullHour(now);
    if (first.day != now.day) {
      return const [];
    }
    final count = _arrivalSlotCount.clamp(0, 24 - first.hour);
    return [
      for (var index = 0; index < count; index++)
        AppTimes.format(TimeOfDay(hour: first.hour + index, minute: 0)),
    ];
  }

  /// True when [label] is still an arrival this visit can take. A future date
  /// takes any time; today takes only a time strictly later than the clock.
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

  /// The visit window, always the arrival time plus two hours.
  AppTimeRange get _visitWindow =>
      AppTimeRange.fromLabel(_arrival, _visitHours) ??
      AppTimeRange(
        start: const TimeOfDay(hour: 10, minute: 0),
        end: const TimeOfDay(hour: 12, minute: 0),
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
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Register visitor'),
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
              color: AppPalette.brandTint,
              borderColor: AppPalette.brandSoft,
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.vpn_key_outlined, color: AppPalette.brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'An alphanumeric access code is generated automatically '
                      'when you register. Share the code with your visitor — no '
                      'QR pass is used.',
                      style: TextStyle(
                        color: AppPalette.mutedStrong,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              fieldKey: const Key('visitor-name-field'),
              label: 'Full name',
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              hint: 'Jamie Johnson',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              fieldKey: const Key('visitor-phone-field'),
              label: 'Contact number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              hint: '+959772611100',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const _Label('Relation'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VisitorRelation.values
                  .map(
                    (relation) => ChoiceChip(
                      label: Text(relation.label),
                      selected: _relation == relation,
                      onSelected: (_) => setState(() => _relation = relation),
                      selectedColor: AppPalette.brandSoft,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _relation == relation
                            ? AppPalette.brand
                            : AppPalette.mutedStrong,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              label: 'Purpose of visit',
              controller: _notesController,
              hint: 'Dinner, delivery, maintenance visit…',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const _Label('Visit date'),
            const SizedBox(height: 8),
            _VisitDatePicker(
              dates: _visitDates,
              selected: _date,
              onSelected: _selectDate,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            const _Label('Arrival time'),
            const SizedBox(height: 8),
            if (_arrivalSlots.isEmpty)
              const _NoSlotsToday()
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in _arrivalSlots)
                    ChoiceChip(
                      key: Key('arrival-slot-$slot'),
                      label: Text(slot),
                      selected: slot == _arrival && !_arrivalIsCustom,
                      onSelected: (_) => setState(() {
                        _arrival = slot;
                        _arrivalIsCustom = false;
                      }),
                      selectedColor: AppPalette.brandSoft,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: slot == _arrival && !_arrivalIsCustom
                            ? AppPalette.brand
                            : AppPalette.mutedStrong,
                      ),
                    ),
                  // Uses the platform time picker already in the project, so no
                  // new package is needed for a custom arrival time.
                  ChoiceChip(
                    key: const Key('arrival-slot-custom'),
                    avatar: Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: _arrivalIsCustom
                          ? AppPalette.brand
                          : AppPalette.mutedStrong,
                    ),
                    label: Text(_arrivalIsCustom ? _arrival : 'Custom time'),
                    selected: _arrivalIsCustom,
                    onSelected: (_) => _pickCustomArrival(context),
                    selectedColor: AppPalette.brandSoft,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _arrivalIsCustom
                          ? AppPalette.brand
                          : AppPalette.mutedStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _VisitWindow(range: _visitWindow),
            ],
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              label: 'Vehicle plate (optional)',
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [UpperCaseTextFormatter()],
              hint: 'ABC-1234',
              icon: Icons.directions_car_outlined,
            ),
            const SizedBox(height: 24),
            AppPrimaryAction(
              key: const Key('submit-visitor'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              isLoading: controller.isSubmitting.value,
              label: controller.isSubmitting.value
                  ? 'Registering...'
                  : 'Register visitor',
              icon: Icons.person_add_alt_1_rounded,
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
      ),
    );
  }

  /// True when the arrival time came from the picker rather than a preset chip.
  /// Tracked explicitly so the chip keeps showing the time the resident chose,
  /// even when that time happens to match a preset.
  bool _arrivalIsCustom = false;

  /// Changes the visit date and re-checks the arrival time against it. Coming
  /// back to today with a time that has since gone moves the selection to the
  /// first slot still on offer, and a custom time stays put whenever the new date
  /// can still take it.
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

  /// Opens the platform time picker. Dismissing it leaves the current arrival
  /// time exactly as it was, and a time that has already gone is refused rather
  /// than quietly accepted, so the custom picker cannot be used to book a visitor
  /// into the past.
  Future<void> _pickCustomArrival(BuildContext context) async {
    final now = TimeOfDay.now();
    final current = AppTimes.parse(_arrival);
    // Today opens on the next full hour rather than on a time that is past,
    // because that is the earliest thing this date can take.
    final opening = _canArriveAt(_arrival)
        ? current
        : (_isToday
              ? TimeOfDay(hour: now.hour + 1, minute: 0)
              : const TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Choose an arrival time',
    );
    if (picked == null || !mounted) {
      return;
    }
    if (!_canArriveAt(AppTimes.format(picked))) {
      setState(
        () => _error =
            'Choose an arrival time later than the current time for today.',
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
      setState(() => _error = 'Visitor name is required.');
      return;
    }
    if (_phoneController.text.trim().length < 6) {
      setState(() => _error = 'Enter a contact number for the visitor.');
      return;
    }
    if (_date.isEmpty) {
      setState(() => _error = 'Choose a visit date.');
      return;
    }
    if (_arrival.isEmpty) {
      setState(() => _error = 'Choose an arrival time.');
      return;
    }
    if (!_canArriveAt(_arrival)) {
      setState(
        () => _error =
            'Choose an arrival time later than the current time for today.',
      );
      return;
    }
    final window = _visitWindow;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Register visitor?',
      message:
          '$name will receive an alphanumeric access code valid on $_date '
          'from ${window.label}.',
      confirmLabel: 'Register',
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
      // The model already carries a window, so the two hour visit is stored
      // rather than recalculated by each screen.
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
        _error = controller.errorMessage.value ?? 'Registration failed.';
      });
      return;
    }
    Get.offNamed(AppRoutes.visitorPass, arguments: visitor);
  }
}

/// Day cards for the visit date: the relative label, the day number and the
/// month, with the selected day clearly filled in.
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
              onTap: () => onSelected(dates[index].value),
            ),
          ),
          if (index < dates.length - 1) const SizedBox(width: 8),
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
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.relative}, ${date.day} ${date.month}',
      child: Material(
        color: selected ? AppPalette.brand : AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? AppPalette.brand : AppPalette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date.relative,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? AppPalette.brandOnDark : AppPalette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date.day,
                  style: TextStyle(
                    color: selected ? Colors.white : AppPalette.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  date.month,
                  style: TextStyle(
                    color: selected ? AppPalette.brandOnDark : AppPalette.muted,
                    fontSize: 10.5,
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

/// Shows the visit window the arrival time produces, so the end time is never
/// something the resident has to work out.
/// Stands in for the chips when the day is too far gone to book against. Late in
/// the evening there is no full hour left today, and rather than offer a time
/// that has already gone the resident is told to pick another date.
class _NoSlotsToday extends StatelessWidget {
  const _NoSlotsToday();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: AppPalette.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'No arrival times are left today. Choose a later visit date.',
              style: const TextStyle(
                color: AppPalette.mutedStrong,
                fontSize: 12,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.brandTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.brandSoft),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timelapse_rounded,
            size: 18,
            color: AppPalette.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit time',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  range.label,
                  style: const TextStyle(
                    color: AppPalette.brand,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '2 hours',
            style: const TextStyle(
              color: AppPalette.mutedStrong,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }
}
