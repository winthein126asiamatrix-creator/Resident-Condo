import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../domain/entities/condo_service.dart';

class CondoServiceRemoteDataSource {
  const CondoServiceRemoteDataSource(this._service);

  final DioApiService _service;

  Future<List<CondoService>> getServices() async {
    final response = await _service.get<dynamic>(ApiEndPoints.services);
    // A response that does not carry an item list is not an empty catalogue.
    // Throwing keeps the repository from overwriting a good cached snapshot
    // with "no services" because of an unexpected envelope.
    if (response is! Map || response['items'] is! List) {
      throw const FormatException('Unexpected services response.');
    }
    return (response['items'] as List)
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
    if (response is! Map || response['items'] is! List) {
      // Same rule as the catalogue: an unexpected shape must not replace the
      // requests already cached for this account with an empty page.
      throw const FormatException('Unexpected service requests response.');
    }
    final items = (response['items'] as List)
        .whereType<Map>()
        .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final currentPage = _asInt(response['page']) ?? page;
    final limit =
        _asInt(response['limit']) ?? (items.isEmpty ? 20 : items.length);
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
        'qty': ?quantity,
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
