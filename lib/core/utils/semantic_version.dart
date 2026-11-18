abstract final class SemanticVersion {
  static int? compare(String? a, String? b) {
    final left = _parse(a);
    final right = _parse(b);
    if (left == null || right == null) return null;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < left.length ? left[index] : 0;
      final rightPart = index < right.length ? right[index] : 0;
      if (leftPart != rightPart) return leftPart < rightPart ? -1 : 1;
    }
    return 0;
  }

  static bool isLower(String? installed, String? target) =>
      compare(installed, target) == -1;

  static List<int>? _parse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final withoutPrefix = value.startsWith('v') || value.startsWith('V')
        ? value.substring(1)
        : value;
    final core = withoutPrefix.split('+').first.split('-').first;
    final parts = core.split('.');
    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null) {
        if (numbers.isEmpty) return null;
        break;
      }
      numbers.add(number);
    }
    return numbers.isEmpty ? null : numbers;
  }
}
