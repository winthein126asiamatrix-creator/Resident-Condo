import '../entities/sample.dart';
import '../repositories/sample_repository.dart';

class SampleUseCases {
  const SampleUseCases(this.repository);

  final SampleRepository repository;

  Future<List<Sample>> getSamples() {
    return repository.getSamples();
  }

  Future<void> addSample(Sample sample) {
    return repository.addSample(sample);
  }

  Future<void> updateSample(Sample sample) {
    return repository.updateSample(sample);
  }

  Future<void> deleteSample(String id) {
    return repository.deleteSample(id);
  }

  Future<void> toggleSample(String id) {
    return repository.toggleSample(id);
  }
}
