import '../../domain/entities/unit.dart';

abstract interface class UnitRepository {
  Future<Unit> getMyUnit();
}
