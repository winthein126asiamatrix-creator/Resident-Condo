import 'package:flutter_test/flutter_test.dart';

import 'package:test/features/dashboard/data/datasources/dashboard_local_data_source.dart';
import 'package:test/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:test/features/dashboard/domain/usecases/dashboard_usecases.dart';

void main() {
  test('loads the mock resident dashboard through use cases', () async {
    final repository = DashboardRepositoryImpl(DashboardLocalDataSource());
    final dashboard = await DashboardUseCases(repository).getDashboard();

    expect(dashboard.resident.name, 'Alex Johnson');
    expect(dashboard.resident.role, 'Owner');
    expect(dashboard.unit.unit, '1205');
    expect(dashboard.balance.outstanding, 462.40);
    expect(dashboard.maintenance, hasLength(2));
    expect(dashboard.reservations, hasLength(2));
    expect(dashboard.announcements, hasLength(3));
  });
}
