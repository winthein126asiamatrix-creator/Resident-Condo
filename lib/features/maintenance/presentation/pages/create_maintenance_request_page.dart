import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/app_validators.dart';
import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';

class CreateMaintenanceRequestPage extends StatefulWidget {
  const CreateMaintenanceRequestPage({super.key});

  @override
  State<CreateMaintenanceRequestPage> createState() =>
      _CreateMaintenanceRequestPageState();
}

class _CreateMaintenanceRequestPageState
    extends State<CreateMaintenanceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _photoLabels = <String>[];
  MaintenanceCategory _category = MaintenanceCategory.plumbing;
  MaintenancePriority _priority = MaintenancePriority.medium;
  DateTime _preferredDate = DateTime(2026, 9, 30);
  TimeOfDay _preferredTime = const TimeOfDay(hour: 10, minute: 0);

  MaintenanceController get controller => Get.find<MaintenanceController>();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: Form(
        key: _formKey,
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'Tell us what needs attention',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2B2A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Our maintenance team will review your request and follow up shortly.',
                style: TextStyle(color: Color(0xFF71807D)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('maintenance-title'),
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    AppValidators.requiredText(value, field: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaintenanceCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: MaintenanceCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('maintenance-location'),
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) =>
                    AppValidators.requiredText(value, field: 'Location'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('maintenance-description'),
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) =>
                    AppValidators.requiredText(value, field: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaintenancePriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: MaintenancePriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: 20),
              const Text(
                'Preferred date and time',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 17),
                      label: Text(_dateLabel(_preferredDate)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(_preferredTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Photos',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Photos are optional in this local demo.',
                style: TextStyle(color: Color(0xFF71807D), fontSize: 12),
              ),
              const SizedBox(height: 9),
              if (_photoLabels.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _photoLabels
                      .map(
                        (label) => Chip(
                          avatar: const Icon(Icons.photo_outlined, size: 17),
                          label: Text(label),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addMockPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Attach mock photo'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('submit-maintenance-request'),
                onPressed: controller.isSubmitting.value ? null : _submit,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  controller.isSubmitting.value
                      ? 'Submitting...'
                      : 'Submit request',
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
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    if (selected != null) setState(() => _preferredDate = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _preferredTime,
    );
    if (selected != null) setState(() => _preferredTime = selected);
  }

  void _addMockPhoto() {
    setState(
      () => _photoLabels.add('Photo ${_photoLabels.length + 1} attached'),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final request = await controller.createRequest(
      title: _titleController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      priority: _priority,
      preferredDate: _dateLabel(_preferredDate),
      preferredTime: _preferredTime.format(context),
      photoNames: _photoLabels,
    );
    if (request != null && mounted) {
      Get.back(result: request);
      Get.snackbar(
        'Request submitted',
        '${request.title} is now with the maintenance team.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
