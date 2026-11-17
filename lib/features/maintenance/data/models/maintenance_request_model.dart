import '../../domain/entities/maintenance_request.dart';

class MaintenanceRequestModel extends MaintenanceRequest {
  const MaintenanceRequestModel({
    required super.id,
    super.reference,
    required super.title,
    required super.categoryCode,
    required super.categoryLabel,
    required super.description,
    required super.location,
    super.unit,
    required super.priority,
    required super.status,
    required super.createdAt,
    required super.preferredDate,
    required super.preferredTime,
    super.photoCount,
    super.technician,
    super.completedAt,
    super.cancelledAt,
    super.timezone,
    super.photos,
    super.progressHistory,
  });

  factory MaintenanceRequestModel.fromJson(
    Map<String, dynamic> json, {
    MaintenanceRequest? fallback,
  }) {
    final parsed = MaintenanceRequestModelData.fromJson(json);
    if (fallback == null) {
      return MaintenanceRequestModel.fromRequest(parsed);
    }
    final hasPriority = json['priority'] != null;
    final hasStatus = json['status'] != null;
    final hasTimezone = json['timezone'] != null;
    return MaintenanceRequestModel.fromRequest(
      fallback.copyWith(
        id: parsed.id.isEmpty ? fallback.id : parsed.id,
        reference: parsed.reference.isEmpty
            ? fallback.reference
            : parsed.reference,
        title: parsed.title.isEmpty ? fallback.title : parsed.title,
        categoryCode: parsed.categoryCode.isEmpty
            ? fallback.categoryCode
            : parsed.categoryCode,
        categoryLabel: parsed.categoryLabel.isEmpty
            ? fallback.categoryLabel
            : parsed.categoryLabel,
        description: parsed.description.isEmpty
            ? fallback.description
            : parsed.description,
        location: parsed.location.isEmpty ? fallback.location : parsed.location,
        unit: parsed.unit.isEmpty ? fallback.unit : parsed.unit,
        priority: hasPriority ? parsed.priority : fallback.priority,
        status: hasStatus ? parsed.status : fallback.status,
        createdAt: parsed.createdAt.isEmpty
            ? fallback.createdAt
            : parsed.createdAt,
        preferredDate: parsed.preferredDate.isEmpty
            ? fallback.preferredDate
            : parsed.preferredDate,
        preferredTime: parsed.preferredTime.isEmpty
            ? fallback.preferredTime
            : parsed.preferredTime,
        photoCount: parsed.photoCount == 0
            ? fallback.photoCount
            : parsed.photoCount,
        technician: parsed.technician ?? fallback.technician,
        completedAt: parsed.completedAt ?? fallback.completedAt,
        cancelledAt: parsed.cancelledAt ?? fallback.cancelledAt,
        timezone: hasTimezone ? parsed.timezone : fallback.timezone,
        photos: parsed.photos.isEmpty ? fallback.photos : parsed.photos,
        progressHistory: parsed.progressHistory.isEmpty
            ? fallback.progressHistory
            : parsed.progressHistory,
      ),
    );
  }

  factory MaintenanceRequestModel.fromRequest(MaintenanceRequest request) {
    return MaintenanceRequestModel(
      id: request.id,
      reference: request.reference,
      title: request.title,
      categoryCode: request.categoryCode,
      categoryLabel: request.categoryLabel,
      description: request.description,
      location: request.location,
      unit: request.unit,
      priority: request.priority,
      status: request.status,
      createdAt: request.createdAt,
      preferredDate: request.preferredDate,
      preferredTime: request.preferredTime,
      photoCount: request.photoCount,
      technician: request.technician,
      completedAt: request.completedAt,
      cancelledAt: request.cancelledAt,
      timezone: request.timezone,
      photos: request.photos,
      progressHistory: request.progressHistory,
    );
  }

  static MaintenanceRequestModel parse(
    Object? json, {
    MaintenanceRequest? fallback,
  }) {
    var map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    while (map['data'] is Map || map['request'] is Map) {
      final key = map['data'] is Map ? 'data' : 'request';
      final nested = Map<String, dynamic>.from(map[key] as Map);
      map.remove(key);
      map.addAll(nested);
    }
    return MaintenanceRequestModel.fromJson(map, fallback: fallback);
  }

  Map<String, dynamic> toJson() => MaintenanceRequestModelData.toJson(this);
}
