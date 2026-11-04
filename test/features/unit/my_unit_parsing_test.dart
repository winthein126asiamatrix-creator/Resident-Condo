import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/unit/data/models/my_unit_models.dart';

void main() {
  test('parses my unit response with nullable fields', () {
    final response = MyUnitResponse.fromJson(<String, dynamic>{
      'unit': <String, dynamic>{
        'id': 1,
        'label': 'Tower A · Unit 101',
        'number': '101',
        'tower': <String, dynamic>{'id': 1, 'name': 'Tower A'},
        'floor': 1,
        'floor_label': '1st floor',
        'area_m2': 0.0,
        'unit_type': <String, dynamic>{
          'id': 1,
          'name': 'Standard',
          'bedrooms': 1,
          'bathrooms': 1,
        },
        'bedrooms': 1,
        'bathrooms': 1,
        'occupancy': 'occupied',
        'my_role': 'owner',
        'parking_slot': null,
      },
      'my_role': 'owner',
      'people': <String, dynamic>{
        'owner': <String, dynamic>{
          'id': 1,
          'partner_id': 7,
          'name': 'Win Thein',
          'role': 'owner',
          'relationship': null,
          'email': null,
          'phone': '09772611100',
        },
        'residents': <dynamic>[],
        'tenant': null,
      },
      'vehicles': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'model': 'Toyota Corolla',
          'plate': '9A-1234',
          'slot': 'P-101',
          'partner_id': 7,
        },
        <String, dynamic>{
          'id': 2,
          'model': 'Bike',
          'plate': 'X',
          'slot': null,
          'partner_id': null,
        },
      ],
      'permissions': <String, dynamic>{
        'can_view_unit': true,
      },
    });

    expect(response.unit.label, 'Tower A · Unit 101');
    expect(response.people.owner?.name, 'Win Thein');
    expect(response.people.tenant, isNull);
    expect(response.people.residents, isEmpty);
    expect(response.vehicles.length, 2);
    expect(response.vehicles[1].slot, isNull);
    expect(response.vehicles[1].partnerId, isNull);
    expect(response.unit.parkingSlot, isNull);
  });

  test('handles missing vehicles and null owner', () {
    final response = MyUnitResponse.fromJson(<String, dynamic>{
      'unit': <String, dynamic>{
        'id': 2,
        'label': 'Unit',
        'number': '2',
      },
      'people': <String, dynamic>{
        'owner': null,
        'residents': null,
        'tenant': null,
      },
    });
    expect(response.vehicles, isEmpty);
    expect(response.people.owner, isNull);
    expect(response.people.residents, isEmpty);
    expect(response.people.tenant, isNull);
  });
}
