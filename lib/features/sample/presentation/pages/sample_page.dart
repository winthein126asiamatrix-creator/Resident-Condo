import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../core/utils/app_validators.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../domain/entities/sample.dart';


import '../controllers/sample_controller.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';

class SamplePage extends GetView<SampleController> {
  SamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Sample',
        actions: [
          IconButton(
            key: Key('refresh-samples'),
            onPressed: controller.loadSamples,
            tooltip: 'Refresh samples',
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            if (controller.isLoading.value && controller.samples.isNotEmpty)
              LinearProgressIndicator(),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: Key('add-sample'),
        onPressed: () => _openEditor(context),
        icon: Icon(Icons.add),
        label: Text('Add sample'),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (controller.isLoading.value && controller.samples.isEmpty) {
      return Center(child: CircularProgressIndicator());
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
      return AppStateMessage(
        title: 'No samples yet',
        message: 'Add a sample to see the architecture in action.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadSamples,
      child: ListView.separated(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: controller.samples.length,
        separatorBuilder: (_, _) => 8.h.heightBox(),
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
        title: Text('Delete sample?'),
        content: Text('Delete "${sample.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
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
  _SampleCard({
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
              itemBuilder: (_) => [
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
  _SampleEditorDialog({this.sample});

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
              key: Key('sample-title'),
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  AppValidators.requiredText(value, field: 'Title'),
            ),
            12.h.heightBox(),
            TextFormField(
              key: Key('sample-description'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          key: Key('save-sample'),
          onPressed: _save,
          child: Text('Save'),
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
