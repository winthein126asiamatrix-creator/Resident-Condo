import 'package:dio/dio.dart';

import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../domain/entities/maintenance_request.dart';
import '../models/maintenance_request_model.dart';

class MaintenanceRemoteDataSource {
  const MaintenanceRemoteDataSource(this._api);

  final DioApiService _api;

  Future<List<MaintenanceCategoryOption>> getCategories() async {
    final json = await _api.get<Object?>(
      ApiEndPoints.maintenanceCategories,
      parse: (data) => data,
    );
    return _parseCategories(json);
  }

  Future<MaintenancePageResult> getRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
  }) async {
    final json = await _api.get<Object?>(
      ApiEndPoints.maintenanceRequests,
      query: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (category != null && category.isNotEmpty) 'category': category,
      },
      parse: (data) => data,
    );
    return MaintenancePageResult.fromJson(
      json,
      fallbackPage: page,
      fallbackLimit: limit,
    );
  }

  Future<MaintenanceRequest> getRequest(Object id) async {
    final json = await _api.get<Object?>(
      ApiEndPoints.maintenanceRequest(id),
      parse: (data) => data,
    );
    return MaintenanceRequestModel.parse(json);
  }

  Future<MaintenanceSummary> getSummary() async {
    final json = await _api.get<Object?>(
      ApiEndPoints.maintenanceSummary,
      parse: (data) => data,
    );
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    final data = map['data'] ?? map['summary'] ?? map;
    return MaintenanceSummary.fromJson(data);
  }

  Future<MaintenanceRequest> createRequest({
    required String title,
    required String categoryCode,
    required String description,
    required String location,
    required MaintenancePriority priority,
    required String preferredDate,
    required String preferredTime,
    List<MaintenancePhotoUpload> photos = const <MaintenancePhotoUpload>[],
  }) async {
    final fields = <String, dynamic>{
      'title': title,
      'category': categoryCode,
      'description': description,
      'location': location,
      'priority': priority.apiValue,
      'preferred_date': preferredDate,
      'preferred_time': preferredTime,
    };

    Object? json;
    if (photos.isEmpty) {
      json = await _api.post<Object?>(
        ApiEndPoints.maintenanceRequests,
        data: fields,
        parse: (data) => data,
      );
    } else {
      json = await _api.uploadMultipart<Object?>(
        ApiEndPoints.maintenanceRequests,
        fields: fields,
        fileGroups: <String, List<MultipartFile>>{
          'photos[]': photos.map(_toMultipartFile).toList(),
        },
        parse: (data) => data,
      );
    }

    final fallback = MaintenanceRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      categoryCode: categoryCode,
      categoryLabel: MaintenanceCategory.fromCode(categoryCode).label,
      description: description,
      location: location,
      priority: priority,
      status: MaintenanceStatus.submitted,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      photoCount: photos.length,
    );

    if (json is Map) {
      return MaintenanceRequestModel.parse(json, fallback: fallback);
    }
    return fallback;
  }

  Future<MaintenanceCancellation> cancelRequest({
    required String id,
    required String reason,
  }) async {
    final json = await _api.post<Object?>(
      ApiEndPoints.maintenanceCancel(id),
      data: <String, dynamic>{'reason': reason},
      parse: (data) => data,
    );
    var map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    while (map['data'] is Map || map['cancellation'] is Map) {
      final key = map['data'] is Map ? 'data' : 'cancellation';
      final nested = Map<String, dynamic>.from(map[key] as Map);
      map.remove(key);
      map.addAll(nested);
    }
    return MaintenanceCancellation.fromJson(map, fallbackId: id);
  }

  MultipartFile _toMultipartFile(MaintenancePhotoUpload photo) =>
      MultipartFile.fromFileSync(photo.path, filename: photo.name);

  List<MaintenanceCategoryOption> _parseCategories(Object? json) {
    Object? raw = json;
    while (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final next = map['items'] ?? map['categories'] ?? map['data'];
      if (next == null || identical(next, raw)) break;
      raw = next;
    }
    if (raw is! List) {
      return const <MaintenanceCategoryOption>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => MaintenanceCategoryOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((option) => option.isActive && option.code.isNotEmpty)
        .toList();
  }
}
