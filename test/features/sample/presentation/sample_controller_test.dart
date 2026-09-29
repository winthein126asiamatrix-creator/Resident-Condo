import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/sample/data/datasources/sample_local_data_source.dart';
import 'package:test/features/sample/data/models/sample_model.dart';
import 'package:test/features/sample/data/repositories/sample_repository_impl.dart';
import 'package:test/features/sample/domain/entities/sample.dart';
import 'package:test/features/sample/domain/repositories/sample_repository.dart';
import 'package:test/features/sample/domain/usecases/sample_usecases.dart';
import 'package:test/features/sample/presentation/bindings/sample_binding.dart';
import 'package:test/features/sample/presentation/controllers/sample_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('binding provides the inward dependency graph', () async {
    SampleBinding().dependencies();

    expect(Get.find<SampleRepository>(), isA<SampleRepositoryImpl>());
    expect(Get.find<SampleUseCases>(), isA<SampleUseCases>());

    final controller = Get.find<SampleController>();
    expect(controller.useCases.repository, isA<SampleRepositoryImpl>());

    await controller.loadSamples();
    expect(controller.samples, isEmpty);
  });

  test('controller performs CRUD through use cases', () async {
    final repository = SampleRepositoryImpl(SampleLocalDataSource());
    final controller = SampleController(SampleUseCases(repository));

    await controller.addSample(title: 'One', description: 'First');
    expect(controller.samples.single.title, 'One');

    final sample = controller.samples.single;
    await controller.updateSample(
      sample: sample,
      title: 'Updated',
      description: 'Changed',
    );
    expect(controller.samples.single.title, 'Updated');

    await controller.toggleSample(sample.id);
    expect(controller.samples.single.isActive, isFalse);

    await controller.deleteSample(sample.id);
    expect(controller.samples, isEmpty);
  });

  test('repository maps models to domain entities', () async {
    final repository = SampleRepositoryImpl(
      SampleLocalDataSource(
        initialItems: [
          const SampleModel(
            id: '1',
            title: 'Mapped',
            description: 'Entity',
            isActive: true,
          ),
        ],
      ),
    );

    final samples = await repository.getSamples();
    expect(samples.single, isA<Sample>());
    expect(samples.single.title, 'Mapped');
  });
}
