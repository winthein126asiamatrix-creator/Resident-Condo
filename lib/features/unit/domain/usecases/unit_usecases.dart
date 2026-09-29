import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

class UnitUseCases {
  const UnitUseCases(this.repository);

  final UnitRepository repository;

  Future<Unit> getMyUnit() {
    return repository.getMyUnit();
  }
}
