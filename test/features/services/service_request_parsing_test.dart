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
}
