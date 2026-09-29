import '../entities/sample.dart';

abstract interface class SampleRepository {
  Future<List<Sample>> getSamples();

  Future<void> addSample(Sample sample);

  Future<void> updateSample(Sample sample);

  Future<void> deleteSample(String id);

  Future<void> toggleSample(String id);
}
