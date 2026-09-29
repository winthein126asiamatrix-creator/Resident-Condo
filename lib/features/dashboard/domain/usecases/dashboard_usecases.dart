import '../entities/dashboard.dart';
import '../repositories/dashboard_repository.dart';

class DashboardUseCases {
  const DashboardUseCases(this.repository);

  final DashboardRepository repository;

  Future<DashboardData> getDashboard() {
    return repository.getDashboard();
  }
}
