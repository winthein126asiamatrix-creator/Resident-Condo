import '../../domain/entities/dashboard.dart';

class DashboardModel extends DashboardData {
  const DashboardModel({
    required super.resident,
    required super.unit,
    required super.balance,
    required super.maintenance,
    required super.inProgressMaintenance,
    required super.completedMaintenance,
    required super.reservations,
    required super.announcements,
  });
}
