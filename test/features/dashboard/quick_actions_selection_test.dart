import 'package:test/features/config/domain/entities/condo_config.dart';
import 'package:test/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter_test/flutter_test.dart';

CondoConfig _configWith(Map<String, bool> features) =>
    CondoConfig.fromJson(<String, dynamic>{'features': features});

void main() {
  test('uses the API sample order and excludes dashboard', () {
    final config = _configWith(<String, bool>{
      'dashboard': true,
      'payments': true,
      'maintenance': true,
      'condo_services': true,
      'facilities': true,
      'complaints': true,
      'visitors': true,
      'parking': true,
      'rules_violations': true,
      'violation_appeals': true,
      'partial_payment': false,
      'lease': true,
      'convenience_store': true,
    });

    expect(selectDashboardQuickActionFeatures(config), <CondoFeature>[
      CondoFeature.payments,
      CondoFeature.maintenance,
      CondoFeature.condoServices,
      CondoFeature.facilities,
      CondoFeature.complaints,
      CondoFeature.visitors,
    ]);
  });

  test('keeps fewer than six enabled features in their original order', () {
    final config = _configWith(<String, bool>{
      'dashboard': true,
      'visitors': true,
      'payments': true,
    });

    expect(selectDashboardQuickActionFeatures(config), <CondoFeature>[
      CondoFeature.payments,
      CondoFeature.visitors,
    ]);
  });

  test('takes only the first six enabled features', () {
    final config = _configWith(<String, bool>{
      for (final feature in CondoFeature.values) feature.wire: true,
    });

    expect(selectDashboardQuickActionFeatures(config), <CondoFeature>[
      CondoFeature.payments,
      CondoFeature.maintenance,
      CondoFeature.condoServices,
      CondoFeature.facilities,
      CondoFeature.complaints,
      CondoFeature.visitors,
    ]);
  });

  test(
    'returns nothing when only dashboard is enabled or config is absent',
    () {
      final config = _configWith(<String, bool>{'dashboard': true});

      expect(selectDashboardQuickActionFeatures(config), isEmpty);
      expect(selectDashboardQuickActionFeatures(null), isEmpty);
    },
  );
}
