import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/lease.dart';
import '../models/lease_model.dart';

class LeaseRemoteDataSource {
  const LeaseRemoteDataSource(this._service);

  final DioApiService _service;

  Future<List<Lease>> getLeases() async {
    final response = await _service.get<dynamic>(ApiEndPoints.lease);
    return _items(
      response,
      listKeys: const <String>['items', 'leases'],
      singleKeys: const <String>['lease'],
    ).map(LeaseModel.fromJson).toList();
  }

  Future<List<LeaseRenewal>> getRenewals() async {
    final response = await _service.get<dynamic>(ApiEndPoints.leaseRenewals);
    return _items(
      response,
      listKeys: const <String>['items', 'renewals', 'renewal_requests'],
      singleKeys: const <String>['renewal'],
    ).map(LeaseRenewalModel.fromJson).toList();
  }

  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) async {
    final response = await _service.post<dynamic>(
      ApiEndPoints.leaseRenewals,
      data: <String, dynamic>{
        'lease_id': _idPayload(renewal.leaseId),
        'proposed_start': _isoDate(renewal.proposedStart),
        'proposed_end': _isoDate(renewal.proposedEnd),
        'proposed_rent': renewal.proposedRent,
        if (renewal.note.trim().isNotEmpty) 'note': renewal.note.trim(),
      },
    );

    final payload = _object(response, keys: const <String>['renewal', 'item']);
    if (payload == null) {
      throw const FormatException('Unexpected renewal response.');
    }
    return LeaseRenewalModel.fromJson(payload);
  }

  Future<LeaseRenewal> withdrawRenewal(LeaseRenewal renewal) async {
    final response = await _service.patch<dynamic>(
      ApiEndPoints.leaseRenewal(_idPayload(renewal.id)),
      data: const <String, dynamic>{'status': 'withdrawn'},
    );

    final payload = _object(response, keys: const <String>['renewal', 'item']);
    if (payload != null) {
      try {
        return LeaseRenewalModel.fromJson(payload);
      } on FormatException {
        // A 2xx with a status-only body still means the withdrawal was
        // accepted; fall through to the requested state.
      }
    }
    return renewal.copyWith(
      status: RenewalStatus.withdrawn,
      decidedOn: AppDates.format(DateTime.now()),
    );
  }

  List<Map<String, dynamic>> _items(
    Object? response, {
    required List<String> listKeys,
    required List<String> singleKeys,
  }) {
    final payload = _unwrap(response);
    if (payload is List) {
      return payload.map(_asMap).toList();
    }
    if (payload is Map) {
      for (final key in listKeys) {
        final value = payload[key];
        if (value is List) {
          return value.map(_asMap).toList();
        }
      }
      for (final key in singleKeys) {
        final value = payload[key];
        if (value is Map) {
          return <Map<String, dynamic>>[Map<String, dynamic>.from(value)];
        }
      }
      if (payload['id'] != null) {
        return <Map<String, dynamic>>[Map<String, dynamic>.from(payload)];
      }
    }
    throw const FormatException('Unexpected lease response.');
  }

  Map<String, dynamic>? _object(
    Object? response, {
    List<String> keys = const [],
  }) {
    final payload = _unwrap(response);
    if (payload is Map) {
      for (final key in keys) {
        final value = payload[key];
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      if (payload['id'] != null) {
        return Map<String, dynamic>.from(payload);
      }
    }
    return null;
  }

  Object? _unwrap(Object? response) {
    if (response is Map) {
      for (final key in const <String>['data', 'result']) {
        final value = response[key];
        if (value is Map || value is List) {
          return value;
        }
      }
    }
    return response;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Unexpected lease list item.');
    }
    return Map<String, dynamic>.from(value);
  }

  Object _idPayload(String id) => int.tryParse(id) ?? id;

  String _isoDate(String value) {
    final iso = DateTime.tryParse(value);
    final date = iso ?? AppDates.parse(value);
    if (iso == null &&
        AppDates.format(date).toLowerCase() != value.trim().toLowerCase()) {
      throw FormatException('Invalid renewal date: $value');
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
