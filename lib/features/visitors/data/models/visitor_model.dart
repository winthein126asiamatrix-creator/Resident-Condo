import '../../domain/entities/visitor.dart';

class VisitorModel extends Visitor {
  const VisitorModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.relation,
    required super.purpose,
    required super.date,
    required super.arrivalWindow,
    required super.status,
    required super.accessCode,
    required super.registeredBy,
    required super.registeredOn,
    super.vehiclePlate,
    super.notes,
    super.checkedInAt,
    super.checkedOutAt,
  });
}
