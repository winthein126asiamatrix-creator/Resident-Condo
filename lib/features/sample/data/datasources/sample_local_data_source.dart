import '../../../../core/errors/app_exception.dart';
import '../models/sample_model.dart';

class SampleLocalDataSource {
  SampleLocalDataSource({List<SampleModel>? initialItems})
    : _items = List<SampleModel>.of(initialItems ?? const <SampleModel>[]);

  final List<SampleModel> _items;

  Future<List<SampleModel>> getSamples() async {
    return List<SampleModel>.unmodifiable(_items);
  }

  Future<void> addSample(SampleModel sample) async {
    if (_items.any((item) => item.id == sample.id)) {
      throw const AppException('A sample with this id already exists.');
    }
    _items.add(sample);
  }

  Future<void> updateSample(SampleModel sample) async {
    final index = _indexOf(sample.id);
    _items[index] = sample;
  }

  Future<void> deleteSample(String id) async {
    final index = _indexOf(id);
    _items.removeAt(index);
  }

  Future<void> toggleSample(String id) async {
    final index = _indexOf(id);
    final item = _items[index];
    _items[index] = SampleModel(
      id: item.id,
      title: item.title,
      description: item.description,
      isActive: !item.isActive,
    );
  }

  int _indexOf(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const AppException('The sample could not be found.');
    }
    return index;
  }
}
