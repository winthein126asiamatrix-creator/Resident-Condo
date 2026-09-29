import '../../domain/entities/sample.dart';
import '../../domain/repositories/sample_repository.dart';
import '../datasources/sample_local_data_source.dart';
import '../models/sample_model.dart';

class SampleRepositoryImpl implements SampleRepository {
  const SampleRepositoryImpl(this.localDataSource);

  final SampleLocalDataSource localDataSource;

  @override
  Future<List<Sample>> getSamples() async {
    final models = await localDataSource.getSamples();
    return models.cast<Sample>();
  }

  @override
  Future<void> addSample(Sample sample) {
    return localDataSource.addSample(SampleModel.fromEntity(sample));
  }

  @override
  Future<void> updateSample(Sample sample) {
    return localDataSource.updateSample(SampleModel.fromEntity(sample));
  }

  @override
  Future<void> deleteSample(String id) {
    return localDataSource.deleteSample(id);
  }

  @override
  Future<void> toggleSample(String id) {
    return localDataSource.toggleSample(id);
  }
}
