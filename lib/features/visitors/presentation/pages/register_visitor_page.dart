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
  String _date = 'Sep 25, 2026';
  String _arrival = '2:00 PM';
  String _departure = '6:00 PM';
  String _error = '';

  static const _dates = ['Sep 25, 2026', 'Sep 26, 2026', 'Sep 27, 2026'];
  static const _slots = ['10:00 AM', '12:00 PM', '2:00 PM', '4:00 PM', '6:00 PM'];

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
      appBar: AppBar(title: const Text('Register visitor')),
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
            const SizedBox(height: 20),
            const _Label('Full name'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('visitor-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Jamie Johnson'),
            ),
            const SizedBox(height: 16),
            const _Label('Contact number'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('visitor-phone-field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: const InputDecoration(hintText: '+1 555 018 2244'),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            const _Label('Purpose of visit'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Dinner, delivery, maintenance visit…',
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Visit date'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _dates
                  .map(
                    (date) => ChoiceChip(
                      label: Text(date),
                      selected: date == _date,
                      onSelected: (_) => setState(() => _date = date),
                      selectedColor: AppPalette.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Arrival time'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _slots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(slot),
                      selected: slot == _arrival,
                      onSelected: (_) => setState(() {
                        _arrival = slot;
                        _departure = _next(slot);
                      }),
                      selectedColor: AppPalette.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Vehicle plate (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [const UpperCaseTextFormatter()],
              decoration: const InputDecoration(hintText: 'ABC-1234'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('submit-visitor'),
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
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Registering...'
                    : 'Register and generate code',
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
      ),
    );
  }

  String _next(String slot) {
    final index = _slots.indexOf(slot);
    if (index == -1 || index == _slots.length - 1) {
      return '8:00 PM';
    }
    return _slots[index + 1];
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

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Register visitor?',
      message:
          '$name will receive an alphanumeric access code valid on $_date '
          'between $_arrival and $_departure.',
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
      arrivalWindow: '$_arrival – $_departure',
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
