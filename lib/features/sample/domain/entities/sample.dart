class Sample {
  const Sample({
    required this.id,
    required this.title,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final bool isActive;

  Sample copyWith({
    String? id,
    String? title,
    String? description,
    bool? isActive,
  }) {
    return Sample(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}
