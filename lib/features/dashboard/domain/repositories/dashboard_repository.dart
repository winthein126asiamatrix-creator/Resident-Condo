import '../../domain/entities/dashboard.dart';

abstract interface class DashboardRepository {
  Future<DashboardData> getDashboard();
}
