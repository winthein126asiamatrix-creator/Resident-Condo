import 'package:flutter_test/flutter_test.dart';

import 'package:test/features/sample/data/datasources/sample_local_data_source.dart';
import 'package:test/features/sample/data/models/sample_model.dart';

void main() {
  test('supports in-memory CRUD and toggling', () async {
    final dataSource = SampleLocalDataSource();
    final sample = const SampleModel(
      id: '1',
      title: 'First sample',
      description: 'Demonstration',
      isActive: true,
    );

    await dataSource.addSample(sample);
    expect(await dataSource.getSamples(), [sample]);

    final updated = SampleModel(
      id: sample.id,
      title: 'Updated sample',
      description: 'Updated',
      isActive: sample.isActive,
    );
    await dataSource.updateSample(updated);
    expect((await dataSource.getSamples()).single.title, 'Updated sample');

    await dataSource.toggleSample(sample.id);
    expect((await dataSource.getSamples()).single.isActive, isFalse);

    await dataSource.deleteSample(sample.id);
    expect(await dataSource.getSamples(), isEmpty);
  });
}
