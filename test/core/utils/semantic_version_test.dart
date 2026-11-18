import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/utils/semantic_version.dart';

void main() {
  group('SemanticVersion.compare', () {
    test('orders numeric parts', () {
      expect(SemanticVersion.compare('1.0.0', '1.0.1'), -1);
      expect(SemanticVersion.compare('1.10.0', '1.9.0'), 1);
      expect(SemanticVersion.compare('2.0.0', '2.0.0'), 0);
      expect(SemanticVersion.compare('1.0', '1.0.0'), 0);
      expect(SemanticVersion.compare('1.0.1', '1.0'), 1);
    });

    test('accepts a v prefix and ignores pre-release and build metadata', () {
      expect(SemanticVersion.compare('v1.2.3', '1.2.3'), 0);
      expect(SemanticVersion.compare('1.2.3-beta.1', '1.2.3'), 0);
      expect(SemanticVersion.compare('1.2.3+7', '1.2.4'), -1);
    });

    test('returns null when either side is not a version', () {
      expect(SemanticVersion.compare('', '1.0.0'), isNull);
      expect(SemanticVersion.compare('1.0.0', null), isNull);
      expect(SemanticVersion.compare('latest', '1.0.0'), isNull);
    });

    test('isLower compares against a target', () {
      expect(SemanticVersion.isLower('1.0.0', '1.0.1'), isTrue);
      expect(SemanticVersion.isLower('1.0.1', '1.0.1'), isFalse);
      expect(SemanticVersion.isLower(null, '1.0.1'), isFalse);
    });
  });
}
