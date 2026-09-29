import '../../domain/entities/dashboard.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.localDataSource);

  final DashboardLocalDataSource localDataSource;

  @override
  Future<DashboardData> getDashboard() {
    return localDataSource.getDashboard();
  }
}
