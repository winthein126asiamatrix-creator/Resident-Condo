import 'dart:math';

/// Generates the alphanumeric lobby access code for a visitor.
///
/// Codes avoid ambiguous glyphs (0/O, 1/I/L) so they are easy to read out
/// loud and type at the gate. No QR code is generated anywhere.
abstract final class VisitorCodeGenerator {
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final Random _random = Random();

  static String generate({String prefix = 'VIS'}) {
    final first = _pick(3);
    final second = _pick(3);
    return '$prefix $first-$second';
  }

  /// Normalises user input: `vis a7k9qx`, `A7K-9QX` and `A7K 9QX` all match.
  static String normalize(String input) {
    final letters = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (letters.length <= 3) {
      return letters;
    }
    final body = letters.substring(3);
    if (body.length <= 3) {
      return 'VIS $body';
    }
    return 'VIS ${body.substring(0, 3)}-${body.substring(3, 6)}';
  }

  static String _pick(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }
}
