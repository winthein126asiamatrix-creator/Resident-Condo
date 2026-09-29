import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/sample.dart';
import '../controllers/sample_controller.dart';

class SamplePage extends GetView<SampleController> {
  const SamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample'),
        actions: [
          IconButton(
            key: const Key('refresh-samples'),
            onPressed: controller.loadSamples,
            tooltip: 'Refresh samples',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            if (controller.isLoading.value && controller.samples.isNotEmpty)
              const LinearProgressIndicator(),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-sample'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add sample'),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (controller.isLoading.value && controller.samples.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage.value != null && controller.samples.isEmpty) {
      return AppStateMessage(
        title: 'Something went wrong',
        message: controller.errorMessage.value!,
        icon: Icons.error_outline,
        actionLabel: 'Try again',
        onAction: controller.loadSamples,
      );
    }
    if (controller.samples.isEmpty) {
      return const AppStateMessage(
        title: 'No samples yet',
        message: 'Add a sample to see the architecture in action.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadSamples,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: controller.samples.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sample = controller.samples[index];
          return _SampleCard(
            sample: sample,
            onEdit: () => _openEditor(context, sample),
            onDelete: () => _deleteSample(context, sample),
            onToggle: () => controller.toggleSample(sample.id),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, [Sample? sample]) async {
    final result = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => _SampleEditorDialog(sample: sample),
    );
    if (result == null) {
      return;
    }
    if (sample == null) {
      await controller.addSample(
        title: result.title,
        description: result.description,
      );
    } else {
      await controller.updateSample(
        sample: sample,
        title: result.title,
        description: result.description,
      );
    }
  }

  Future<void> _deleteSample(BuildContext context, Sample sample) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sample?'),
        content: Text('Delete "${sample.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await controller.deleteSample(sample.id);
    }
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({
    required this.sample,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Sample sample;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(sample.title),
        subtitle: Text(
          sample.description.isEmpty ? 'No description' : sample.description,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: sample.isActive,
              onChanged: (_) {
                onToggle();
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'Sample actions',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _SampleEditorDialog extends StatefulWidget {
  const _SampleEditorDialog({this.sample});

  final Sample? sample;

  @override
  State<_SampleEditorDialog> createState() => _SampleEditorDialogState();
}

class _SampleEditorDialogState extends State<_SampleEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.sample?.title);
    _descriptionController = TextEditingController(
      text: widget.sample?.description,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.sample == null ? 'Add sample' : 'Edit sample'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('sample-title'),
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  AppValidators.requiredText(value, field: 'Title'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('sample-description'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-sample'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.pop(context, (
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
    ));
  }
}
