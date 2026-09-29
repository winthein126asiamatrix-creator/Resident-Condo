import '../../domain/entities/unit.dart';

class UnitModel extends Unit {
  const UnitModel({
    required super.tower,
    required super.unitNumber,
    required super.floor,
    required super.unitType,
    required super.area,
    required super.bedrooms,
    required super.bathrooms,
    required super.ownershipStatus,
    required super.occupancyStatus,
    required super.owner,
    required super.residents,
    super.tenant,
    required super.parking,
  });
}
