import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/services/domain/entities/condo_service.dart';

void main() {
  test('parses service list item without availability', () {
    final service = CondoService.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Clothing',
      'category': <String, dynamic>{
        'id': 5,
        'code': 'laundry',
        'label': 'Laundry',
      },
      'provider': 'BrightHome Services',
      'description': 'Professional clothing laundry and cleaning service.',
      'icon': false,
      'price': <String, dynamic>{'amount': 30000.0, 'currency': 'USD'},
      'pricing_unit': <String, dynamic>{'label': 'KG', 'text': 'per KG'},
      'notice_days': 2,
    });

    expect(service.category, ServiceCategory.laundry);
    expect(service.providerName, 'BrightHome Services');
    expect(service.price, 30000);
    expect(service.unit, 'KG');
    expect(service.noticeDays, 2);
    expect(service.availableDates, isEmpty);
  });

  test('parses service detail with provider and availability', () {
    final service = CondoService.fromJson(<String, dynamic>{
      'id': 1,
      'category': <String, dynamic>{'id': 5, 'name': 'Laundry'},
      'name': 'Clothing',
      'provider': <String, dynamic>{'id': 17, 'name': 'BrightHome Services'},
      'description': 'Professional clothing laundry and cleaning service.',
      'pricing': <String, dynamic>{
        'type': 'per_unit',
        'amount': 30000.0,
        'currency': 'USD',
        'unit_label': 'KG',
      },
      'estimated_duration_minutes': 120,
      'booking_fields': <dynamic>[
        <String, dynamic>{
          'key': 'quantity',
          'label': 'Quantity',
          'type': 'quantity',
          'required': true,
          'default': 1,
          'min': 1,
          'max': 10,
        },
      ],
      'availability': <String, dynamic>{
        'timezone': 'Asia/Yangon',
        'dates': <dynamic>[
          <String, dynamic>{
            'date': '2026-11-08',
            'slots': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'start_time': '09:00',
                'end_time': '11:00',
                'status': 'available',
                'remaining_capacity': 5,
              },
            ],
          },
          <String, dynamic>{'date': '2026-11-09', 'slots': <dynamic>[]},
        ],
      },
      'is_active': true,
    });

    expect(service.category, ServiceCategory.laundry);
    expect(service.providerName, 'BrightHome Services');
    expect(service.price, 30000);
    expect(service.unit, 'KG');
    expect(service.estimatedDurationMinutes, 120);
    expect(service.bookingFields.single.defaultValue, 1);
    expect(service.availableDates, hasLength(2));
    expect(service.availableDates.first.slots.single.startTime, '09:00');
  });

  test('parses created service request with submitted fallback', () {
    const fallback = ServiceRequest(
      id: 'local',
      serviceId: 1,
      serviceName: 'Clothing',
      category: ServiceCategory.laundry,
      scheduledDate: '2026-11-08',
      scheduledSlot: '09:00 - 11:00',
      status: ServiceRequestStatus.requested,
      price: 30000,
      requestedOn: 'Nov 6, 2026',
      provider: 'BrightHome Services',
      notes: 'Handle with care',
      slotId: 1,
      bookingDetails: <String, dynamic>{'quantity': 2},
    );

    final request = ServiceRequest.fromJson(<String, dynamic>{
      'id': 99,
      'service_id': 1,
      'date': '2026-11-08',
      'start_time': '09:00',
      'end_time': '11:00',
      'slot_id': 1,
      'status': 'requested',
      'note': 'Handle with care',
      'created_at': '2026-11-06T10:00:00',
    }, fallback: fallback);

    expect(request.id, '99');
    expect(request.serviceName, 'Clothing');
    expect(request.category, ServiceCategory.laundry);
    expect(request.scheduledSlot, '09:00 - 11:00');
    expect(request.provider, 'BrightHome Services');
    expect(request.bookingDetails, <String, dynamic>{'quantity': 2});
  });

  test('parses category with false code and nullable provider', () {
    final request = ServiceRequest.fromJson(<String, dynamic>{
      'id': 99,
      'status': 'requested',
      'category': <String, dynamic>{
        'id': 3,
        'code': false,
        'label': 'Laundary',
      },
      'provider': 'Test 1',
    });

    expect(request.categoryInfo?.id, 3);
    expect(request.categoryInfo?.code, isNull);
    expect(request.categoryInfo?.label, 'Laundary');
    expect(request.category, ServiceCategory.laundry);
    expect(request.provider, 'Test 1');
  });

  test('missing or null category and provider are handled safely', () {
    final missing = ServiceRequest.fromJson(<String, dynamic>{
      'id': 1,
      'status': 'requested',
    });
    expect(missing.categoryInfo, isNull);
    expect(missing.provider, isNull);
    expect(missing.category, ServiceCategory.other);

    final nulled = ServiceRequest.fromJson(<String, dynamic>{
      'id': 2,
      'status': 'requested',
      'category': null,
      'provider': null,
    });
    expect(nulled.categoryInfo, isNull);
    expect(nulled.provider, isNull);

    final falseCode = ServiceRequest.fromJson(<String, dynamic>{
      'id': 3,
      'category': <String, dynamic>{
        'id': 3,
        'code': 'false',
        'label': 'Laundary',
      },
      'provider': false,
    });
    expect(falseCode.categoryInfo?.code, isNull);
    expect(falseCode.provider, isNull);
  });

  test('cancel is allowed only for the requested backend status', () {
    ServiceRequest requestFor(
      ServiceRequestStatus status, {
      String? statusLabel,
    }) {
      return ServiceRequest(
        id: '42',
        serviceId: 1,
        serviceName: 'Clothing',
        category: ServiceCategory.laundry,
        scheduledDate: '2026-11-08',
        scheduledSlot: '09:00 - 11:00',
        status: status,
        statusLabel: statusLabel,
        price: 30000,
        requestedOn: 'Nov 6, 2026',
        provider: 'Test 1',
      );
    }

    expect(requestFor(ServiceRequestStatus.requested).canCancel, isTrue);
    expect(
      requestFor(
        ServiceRequestStatus.requested,
        statusLabel: 'Cancelled',
      ).canCancel,
      isTrue,
    );
    for (final status in [
      ServiceRequestStatus.scheduled,
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.completed,
      ServiceRequestStatus.cancelled,
    ]) {
      expect(requestFor(status).canCancel, isFalse);
    }
    expect(
      requestFor(
        ServiceRequestStatus.cancelled,
        statusLabel: 'Requested',
      ).canCancel,
      isFalse,
    );
  });

  test('category info and provider survive cache serialization', () {
    final request = ServiceRequest.fromJson(<String, dynamic>{
      'id': 7,
      'status': 'requested',
      'category': <String, dynamic>{
        'id': 3,
        'code': false,
        'label': 'Laundary',
      },
      'provider': 'Test 1',
    });

    final restored = ServiceRequest.fromJson(request.toJson());

    expect(restored.categoryInfo?.id, 3);
    expect(restored.categoryInfo?.code, isNull);
    expect(restored.categoryInfo?.label, 'Laundary');
    expect(restored.provider, 'Test 1');
    expect(restored.category, ServiceCategory.laundry);
  });

  test('parses the paginated service request list payload', () {
    final response = <String, dynamic>{
      'items': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'code': 'SRV-2026-003',
          'service': <String, dynamic>{
            'id': 1,
            'name': 'Top',
            'icon': false,
            'cancel_minutes': 1440,
          },
          'category': <String, dynamic>{
            'id': 3,
            'code': false,
            'label': 'Laundary',
          },
          'provider': 'Test 1',
          'status': 'submitted',
          'status_label': 'Submitted',
          'is_active': true,
          'date': '2026-11-18',
          'start_time': '08:00',
          'end_time': '09:00',
          'start_at': '2026-11-18T08:00:00Z',
          'end_at': '2026-11-18T09:00:00Z',
          'amount': <String, dynamic>{'amount': 200.0, 'currency': 'USD'},
          'qty': 1,
        },
      ],
      'page': 1,
      'limit': 20,
      'total': 1,
    };

    final items = (response['items'] as List)
        .whereType<Map>()
        .map((item) => ServiceRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    expect(items, hasLength(1));
    final request = items.single;
    expect(request.id, '1');
    expect(request.code, 'SRV-2026-003');
    expect(request.serviceId, 1);
    expect(request.serviceName, 'Top');
    expect(request.categoryInfo?.id, 3);
    expect(request.categoryInfo?.code, isNull);
    expect(request.categoryInfo?.label, 'Laundary');
    expect(request.provider, 'Test 1');
    expect(request.status, ServiceRequestStatus.requested);
    expect(request.displayStatus, 'Submitted');
    expect(request.scheduledDate, '2026-11-18');
    expect(request.scheduledSlot, '08:00 - 09:00');
    expect(request.price, 200);
    expect(request.currency, 'USD');
    expect(request.qty, 1);
  });
}
