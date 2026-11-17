import '../../domain/entities/dashboard.dart';

class DashboardModel extends DashboardData {
  const DashboardModel({
    required super.unit,
    required super.balance,
    required super.reservations,
    required super.announcements,
  });
}
