import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';
import '../datasources/unit_remote_data_source.dart';

class UnitRepositoryImpl implements UnitRepository {
  const UnitRepositoryImpl(this.remoteDataSource);

  final UnitRemoteDataSource remoteDataSource;

  @override
  Future<Unit> getMyUnit() {
    return remoteDataSource.getMyUnit();
  }
}
