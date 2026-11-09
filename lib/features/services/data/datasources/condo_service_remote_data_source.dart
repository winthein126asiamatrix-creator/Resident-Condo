import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../domain/entities/condo_service.dart';

class CondoServiceRemoteDataSource {
  const CondoServiceRemoteDataSource(this._service);

  final DioApiService _service;

  Future<List<CondoService>> getServices() async {
    final response = await _service.get<dynamic>(ApiEndPoints.services);
    if (response is! Map) return const <CondoService>[];
    final items = response['items'];
    if (items is! List) return const <CondoService>[];
    return items
        .whereType<Map>()
        .map((e) => CondoService.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CondoService> getService(int id) async {
    return _service.get<CondoService>(
      ApiEndPoints.service(id),
      parse: CondoService.parse,
    );
  }

  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  }) async {
    final response = await _service.get<dynamic>(
      ApiEndPoints.serviceRequests,
      query: <String, dynamic>{'status': status, 'page': page},
    );
    if (response is! Map) {
      return ServiceRequestPageResult(
        items: const <ServiceRequest>[],
        page: page,
        limit: 20,
        total: 0,
      );
    }
    final itemsJson = response['items'];
    final items = itemsJson is List
        ? itemsJson
              .whereType<Map>()
              .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ServiceRequest>[];
    final currentPage = _asInt(response['page']) ?? page;
    final limit =
        _asInt(response['limit']) ?? (items.length == 0 ? 20 : items.length);
    final total =
        _asInt(response['total']) ?? (currentPage - 1) * limit + items.length;
    return ServiceRequestPageResult(
      items: items,
      page: currentPage,
      limit: limit,
      total: total,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Future<ServiceRequest> createRequest(ServiceRequest request) async {
    final times = _splitSlot(request.scheduledSlot);
    final quantity = _quantityOf(request.bookingDetails);
    return _service.post<ServiceRequest>(
      ApiEndPoints.serviceRequests,
      data: <String, dynamic>{
        'service_id': request.serviceId,
        'date': request.scheduledDate,
        'start_time': times.$1,
        'end_time': times.$2,
        if (request.slotId != null) 'slot_id': request.slotId,
        if (quantity != null) 'qty': quantity,
        if (request.notes.trim().isNotEmpty) 'note': request.notes.trim(),
      },
      parse: (json) {
        final payload = json is Map && json['data'] is Map
            ? json['data']
            : json is Map && json['request'] is Map
            ? json['request']
            : json;
        return ServiceRequest.fromJson(payload, fallback: request);
      },
    );
  }

  (String, String) _splitSlot(String label) {
    final parts = label.split(RegExp(r'\s*[-–]\s*'));
    if (parts.isEmpty) return ('', '');
    if (parts.length == 1) return (parts.first.trim(), parts.first.trim());
    return (parts.first.trim(), parts[1].trim());
  }

  num? _quantityOf(Map<String, dynamic> details) {
    for (final key in const <String>['qty', 'quantity']) {
      final value = details[key];
      if (value is num) return value;
      final parsed = num.tryParse('$value');
      if (parsed != null) return parsed;
    }
    for (final value in details.values) {
      if (value is num) return value;
    }
    return null;
  }
}
