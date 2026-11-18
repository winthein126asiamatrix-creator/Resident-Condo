import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/config/domain/entities/app_config.dart';
import 'package:test/features/config/domain/entities/condo_config.dart';

void main() {
  group('AppConfig', () {
    test('parses the version and maintenance blocks', () {
      final config = AppConfig.parse(<String, dynamic>{
        'app_version': <String, dynamic>{
          'min_supported': '1.2.0',
          'latest': '1.3.0',
          'update_url': 'https://example.com/app',
        },
        'maintenance': <String, dynamic>{
          'enabled': true,
          'message': 'Back soon',
          'ends_at': '2026-11-18T10:00:00Z',
        },
      });

      expect(config.version?.minSupported, '1.2.0');
      expect(config.version?.latest, '1.3.0');
      expect(config.version?.updateUrl, 'https://example.com/app');
      expect(config.maintenance?.enabled, isTrue);
      expect(config.maintenance?.message, 'Back soon');
      expect(
        config.maintenance?.endsAt,
        DateTime.parse('2026-11-18T10:00:00Z'),
      );
    });

    test('defaults a missing maintenance block to inactive', () {
      final config = AppConfig.parse(<String, dynamic>{
        'app_version': <String, dynamic>{
          'latest': '1.0.0',
          'update_url': 'https://example.com/app',
        },
      });

      expect(config.maintenance?.enabled ?? false, isFalse);
      expect(config.version?.minSupported, isNull);
      expect(config.version?.hasUpdateTarget, isTrue);
    });

    test('rejects a response that is not an object', () {
      expect(() => AppConfig.parse(<dynamic>[]), throwsFormatException);
      expect(() => AppConfig.parse(null), throwsFormatException);
    });

    test('round trips through toJson', () {
      final config = AppConfig.parse(<String, dynamic>{
        'app_version': <String, dynamic>{'latest': '2.0.0'},
        'maintenance': <String, dynamic>{'enabled': false},
      });

      final restored = AppConfig.fromJson(config.toJson());
      expect(restored.version?.latest, '2.0.0');
      expect(restored.maintenance?.enabled, isFalse);
    });
  });

  group('CondoConfig', () {
    test('reads every feature flag and defaults unknown ones to false', () {
      final config = CondoConfig.parse(<String, dynamic>{
        'condo': <String, dynamic>{
          'id': 4,
          'name': 'Harbour View',
          'theme_color': '#123456',
        },
        'plan': <String, dynamic>{
          'tier': 'pro',
          'addons': ['parking'],
        },
        'features': <String, dynamic>{
          'payments': true,
          'maintenance': true,
          'partial_payment': false,
          'facilities': true,
          'visitors': true,
          'convenience_store': true,
        },
        'lease': <String, dynamic>{
          'tenant_registration_enabled': true,
          'required_documents': [
            {'key': 'id', 'label': 'ID', 'required': true},
          ],
        },
        'payments': <String, dynamic>{
          'partial_payment_min_amount': 10.5,
          'gateways': [
            {'id': 'card', 'name': 'Card', 'enabled': true},
          ],
        },
        'support': <String, dynamic>{'phone': '+1 555 0100'},
      });

      expect(config.condo?.name, 'Harbour View');
      expect(config.plan?.tier, 'pro');
      expect(config.isFeatureEnabled(CondoFeature.payments), isTrue);
      expect(config.isFeatureEnabled(CondoFeature.maintenance), isTrue);
      expect(config.isFeatureEnabled(CondoFeature.facilities), isTrue);
      expect(config.isFeatureEnabled(CondoFeature.visitors), isTrue);
      expect(config.isFeatureEnabled(CondoFeature.convenienceStore), isTrue);
      expect(config.isFeatureEnabled(CondoFeature.partialPayment), isFalse);
      expect(config.isFeatureEnabled(CondoFeature.lease), isFalse);
      expect(config.isFeatureEnabled(CondoFeature.complaints), isFalse);
      expect(config.lease?.tenantRegistrationEnabled, isTrue);
      expect(config.lease?.requiredDocuments.single.key, 'id');
      expect(config.payments?.partialPaymentMinAmount, 10.5);
      expect(config.payments?.gateways.single.enabled, isTrue);
      expect(config.support?.phone, '+1 555 0100');
    });

    test('ignores unknown fields and missing optional sections', () {
      final config = CondoConfig.parse(<String, dynamic>{
        'features': <String, dynamic>{'payments': true},
        'unexpected': 'value',
      });

      expect(config.isFeatureEnabled(CondoFeature.payments), isTrue);
      expect(config.condo, isNull);
      expect(config.plan, isNull);
      expect(config.lease, isNull);
      expect(config.support, isNull);
    });

    test('rejects a response without a features object', () {
      expect(
        () =>
            CondoConfig.parse(<String, dynamic>{'condo': <String, dynamic>{}}),
        throwsFormatException,
      );
      expect(() => CondoConfig.parse(null), throwsFormatException);
    });
  });
}
