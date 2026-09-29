import '../../domain/entities/sample.dart';

class SampleModel extends Sample {
  const SampleModel({
    required super.id,
    required super.title,
    required super.description,
    required super.isActive,
  });

  factory SampleModel.fromEntity(Sample sample) {
    return SampleModel(
      id: sample.id,
      title: sample.title,
      description: sample.description,
      isActive: sample.isActive,
    );
  }
}
