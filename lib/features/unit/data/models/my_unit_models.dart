/// Parsed representation of `GET /api/v1/my-unit`.
class MyUnitResponse {
  const MyUnitResponse({
    required this.unit,
    this.myRole,
    required this.people,
    this.vehicles = const <UnitVehicle>[],
    this.permissions,
  });

  final UnitInfo unit;
  final String? myRole;
  final UnitPeople people;
  final List<UnitVehicle> vehicles;
  final Map<String, dynamic>? permissions;

  static MyUnitResponse parse(Object? json) {
    if (json is! Map) {
      return MyUnitResponse(
        unit: const UnitInfo(id: 0, label: '', number: ''),
        people: const UnitPeople(),
      );
    }
    return MyUnitResponse.fromJson(Map<String, dynamic>.from(json));
  }

  factory MyUnitResponse.fromJson(Map<String, dynamic> json) {
    final unitJson = json['unit'];
    final peopleJson = json['people'];
    final vehiclesJson = json['vehicles'];
    final permissionsJson = json['permissions'];
    return MyUnitResponse(
      unit: unitJson is Map
          ? UnitInfo.fromJson(Map<String, dynamic>.from(unitJson))
          : const UnitInfo(id: 0, label: '', number: ''),
      myRole: _nullableString(json['my_role']),
      people: peopleJson is Map
          ? UnitPeople.fromJson(Map<String, dynamic>.from(peopleJson))
          : const UnitPeople(),
      vehicles: vehiclesJson is List
          ? vehiclesJson
              .whereType<Map>()
              .map((e) => UnitVehicle.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <UnitVehicle>[],
      permissions: permissionsJson is Map
          ? Map<String, dynamic>.from(permissionsJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'unit': unit.toJson(),
    'my_role': myRole,
    'people': people.toJson(),
    'vehicles': vehicles.map((v) => v.toJson()).toList(),
    'permissions': permissions,
  };
}

class UnitInfo {
  const UnitInfo({
    required this.id,
    required this.label,
    required this.number,
    this.tower,
    this.floor,
    this.floorLabel,
    this.areaM2,
    this.unitType,
    this.bedrooms,
    this.bathrooms,
    this.occupancy,
    this.myRole,
    this.parkingSlot,
  });

  final int id;
  final String label;
  final String number;
  final TowerInfo? tower;
  final int? floor;
  final String? floorLabel;
  final double? areaM2;
  final UnitTypeInfo? unitType;
  final int? bedrooms;
  final int? bathrooms;
  final String? occupancy;
  final String? myRole;
  final String? parkingSlot;

  factory UnitInfo.fromJson(Map<String, dynamic> json) {
    final towerJson = json['tower'];
    final unitTypeJson = json['unit_type'];
    return UnitInfo(
      id: _asInt(json['id']),
      label: _asString(json['label']),
      number: _asString(json['number']),
      tower: towerJson is Map
          ? TowerInfo.fromJson(Map<String, dynamic>.from(towerJson))
          : null,
      floor: _nullableInt(json['floor']),
      floorLabel: _nullableString(json['floor_label']),
      areaM2: _nullableDouble(json['area_m2']),
      unitType: unitTypeJson is Map
          ? UnitTypeInfo.fromJson(Map<String, dynamic>.from(unitTypeJson))
          : null,
      bedrooms: _nullableInt(json['bedrooms']),
      bathrooms: _nullableInt(json['bathrooms']),
      occupancy: _nullableString(json['occupancy']),
      myRole: _nullableString(json['my_role']),
      parkingSlot: _nullableString(json['parking_slot']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'number': number,
    'tower': tower?.toJson(),
    'floor': floor,
    'floor_label': floorLabel,
    'area_m2': areaM2,
    'unit_type': unitType?.toJson(),
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'occupancy': occupancy,
    'my_role': myRole,
    'parking_slot': parkingSlot,
  };
}

class TowerInfo {
  const TowerInfo({required this.id, required this.name});

  final int id;
  final String name;

  factory TowerInfo.fromJson(Map<String, dynamic> json) => TowerInfo(
    id: _asInt(json['id']),
    name: _asString(json['name']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}

class UnitTypeInfo {
  const UnitTypeInfo({
    required this.id,
    required this.name,
    this.bedrooms,
    this.bathrooms,
  });

  final int id;
  final String name;
  final int? bedrooms;
  final int? bathrooms;

  factory UnitTypeInfo.fromJson(Map<String, dynamic> json) => UnitTypeInfo(
    id: _asInt(json['id']),
    name: _asString(json['name']),
    bedrooms: _nullableInt(json['bedrooms']),
    bathrooms: _nullableInt(json['bathrooms']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
  };
}

class UnitPeople {
  const UnitPeople({this.owner, this.residents = const <UnitPerson>[], this.tenant});

  final UnitPerson? owner;
  final List<UnitPerson> residents;
  final UnitPerson? tenant;

  factory UnitPeople.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    final residentsJson = json['residents'];
    final tenantJson = json['tenant'];
    return UnitPeople(
      owner: ownerJson is Map
          ? UnitPerson.fromJson(Map<String, dynamic>.from(ownerJson))
          : null,
      residents: residentsJson is List
          ? residentsJson
              .whereType<Map>()
              .map((e) => UnitPerson.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <UnitPerson>[],
      tenant: tenantJson is Map
          ? UnitPerson.fromJson(Map<String, dynamic>.from(tenantJson))
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'owner': owner?.toJson(),
    'residents': residents.map((r) => r.toJson()).toList(),
    'tenant': tenant?.toJson(),
  };
}

class UnitPerson {
  const UnitPerson({
    required this.id,
    this.partnerId,
    required this.name,
    required this.role,
    this.relationship,
    this.email,
    this.phone,
  });

  final int id;
  final int? partnerId;
  final String name;
  final String role;
  final String? relationship;
  final String? email;
  final String? phone;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UnitPerson.fromJson(Map<String, dynamic> json) => UnitPerson(
    id: _asInt(json['id']),
    partnerId: _nullableInt(json['partner_id']),
    name: _asString(json['name']),
    role: _asString(json['role']),
    relationship: _nullableString(json['relationship']),
    email: _nullableString(json['email']),
    phone: _nullableString(json['phone']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'partner_id': partnerId,
    'name': name,
    'role': role,
    'relationship': relationship,
    'email': email,
    'phone': phone,
  };
}

class UnitVehicle {
  const UnitVehicle({
    required this.id,
    required this.model,
    required this.plate,
    this.slot,
    this.partnerId,
  });

  final int id;
  final String model;
  final String plate;
  final String? slot;
  final int? partnerId;

  factory UnitVehicle.fromJson(Map<String, dynamic> json) => UnitVehicle(
    id: _asInt(json['id']),
    model: _asString(json['model']),
    plate: _asString(json['plate']),
    slot: _nullableString(json['slot']),
    partnerId: _nullableInt(json['partner_id']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'model': model,
    'plate': plate,
    'slot': slot,
    'partner_id': partnerId,
  };
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _nullableInt(Object? value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _nullableDouble(Object? value) {
  if (value == null || value == false) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String _asString(Object? value) => value is String
    ? value
    : (value == null || value == false ? '' : value.toString());

String? _nullableString(Object? value) {
  if (value is! String) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
