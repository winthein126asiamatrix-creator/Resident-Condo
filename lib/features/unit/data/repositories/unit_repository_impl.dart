import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';
import '../datasources/unit_local_data_source.dart';

class UnitRepositoryImpl implements UnitRepository {
  const UnitRepositoryImpl(this.localDataSource);

  final UnitLocalDataSource localDataSource;

  @override
  Future<Unit> getMyUnit() {
    return localDataSource.getMyUnit();
  }
}
