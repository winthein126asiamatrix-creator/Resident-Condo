import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Makes captured API data safe to keep in memory and show in the debug UI.
///
/// Redaction happens before an entry reaches the store, not when the viewer is
/// opened, so a secret never sits in an unredacted log waiting to be displayed.
/// The walk is bounded in depth, entries and string length, which keeps a large
/// response from turning logging into a main-thread stall.
abstract final class ApiLogRedactor {
  static const String mask = '***';
  static const int maxStringLength = 4000;
  static const int maxEntries = 100;
  static const int maxDepth = 8;

  /// Total characters kept for one body, across every nested string.
  ///
  /// Individual strings are capped too, but this is what stops a body made of
  /// many medium strings from adding up. At 200 logs the whole store stays a
  /// few megabytes rather than growing with whatever the backend returned.
  static const int maxBodyCharacters = 12000;

  static final _nonAlphanumeric = RegExp(r'[^a-z0-9]');
  static final _bearer = RegExp(
    r'''\b(Bearer|Basic)\s+[^\s"'},]+''',
    caseSensitive: false,
  );
  static final _sensitiveText = RegExp(
    r'''((?:access_token|refresh_token|password|passcode|otp|api_key|apikey)\s*[:=]\s*)[^&\s,"'}]+''',
    caseSensitive: false,
  );

  static const _sensitiveHeaders = <String>{
    'authorization',
    'proxyauthorization',
    'cookie',
    'setcookie',
    'xapikey',
    'xauthtoken',
    'xcsrftoken',
  };

  static const _sensitiveFields = <String>{
    'password',
    'passcode',
    'pwd',
    'newpassword',
    'confirmpassword',
    'currentpassword',
    'token',
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'otp',
    'otpcode',
    'onetimepassword',
    'apikey',
    'secret',
    'clientsecret',
    'cardnumber',
    'cvv',
    'cvc',
    'pin',
    'accountnumber',
    'iban',
    'routingnumber',
    'ssn',
  };

  static String _normalize(Object? key) =>
      '$key'.toLowerCase().replaceAll(_nonAlphanumeric, '');

  static bool isSensitiveKey(Object? key) {
    final normalized = _normalize(key);
    if (normalized.isEmpty) {
      return false;
    }
    if (_sensitiveFields.contains(normalized)) {
      return true;
    }
    if (normalized.contains('password') ||
        normalized.contains('passcode') ||
        normalized.contains('secret') ||
        normalized.contains('apikey')) {
      return true;
    }
    if (normalized.endsWith('token')) {
      return true;
    }
    if (normalized.startsWith('otp') || normalized.endsWith('otp')) {
      return true;
    }
    if (normalized.contains('cardnumber') ||
        normalized == 'cvv' ||
        normalized == 'cvc' ||
        normalized == 'pin') {
      return true;
    }
    return normalized.contains('accountnumber') ||
        normalized == 'iban' ||
        normalized.contains('routingnumber') ||
        normalized == 'ssn';
  }

  static Map<String, String> redactHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) {
      return const <String, String>{};
    }
    final safe = <String, String>{};
    headers.forEach((key, value) {
      final normalized = _normalize(key);
      safe[key] = _sensitiveHeaders.contains(normalized) || isSensitiveKey(key)
          ? mask
          : _headerValue(value);
    });
    return safe;
  }

  static Map<String, Object?> redactQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) {
      return const <String, Object?>{};
    }
    final safe = <String, Object?>{};
    var count = 0;
    for (final entry in query.entries) {
      if (count++ >= maxEntries) {
        safe['<truncated>'] = '<${query.length - maxEntries} more>';
        break;
      }
      safe[entry.key] = isSensitiveKey(entry.key) ? mask : value(entry.value);
    }
    return safe;
  }

  /// Returns a bounded, redacted copy of [input] suitable for storage.
  static Object? value(Object? input) =>
      _value(input, 0, _Budget(maxBodyCharacters));

  static Object? _value(Object? input, int depth, _Budget budget) {
    if (budget.exhausted) {
      return '<truncated: log size limit>';
    }
    if (input == null || input is num || input is bool) {
      return input;
    }
    if (depth >= maxDepth) {
      return '<truncated: nesting limit>';
    }
    if (input is String) {
      return budget.take(truncateText(input));
    }
    if (input is Uint8List || input is ByteBuffer) {
      return budget.take(
        '<binary ${input is Uint8List ? input.length : (input as ByteBuffer).lengthInBytes} bytes>',
      );
    }
    if (input is List<int>) {
      return budget.take('<binary ${input.length} bytes>');
    }
    if (input is FormData) {
      return _formData(input, budget);
    }
    if (input is MultipartFile) {
      return _multipartFile(input);
    }
    if (input is Map) {
      final safe = <String, Object?>{};
      var count = 0;
      for (final entry in input.entries) {
        if (budget.exhausted) {
          safe['<truncated>'] = '<size limit>';
          break;
        }
        if (count++ >= maxEntries) {
          safe['<truncated>'] = '<${input.length - maxEntries} more>';
          break;
        }
        final key = '${entry.key}';
        safe[key] = isSensitiveKey(key)
            ? mask
            : _value(entry.value, depth + 1, budget);
      }
      return safe;
    }
    if (input is Iterable) {
      final safe = <Object?>[];
      var count = 0;
      for (final item in input) {
        if (budget.exhausted) {
          safe.add('<truncated: size limit>');
          break;
        }
        if (count++ >= maxEntries) {
          safe.add('<truncated: more than $maxEntries items>');
          break;
        }
        safe.add(_value(item, depth + 1, budget));
      }
      return safe;
    }
    if (input is DateTime || input is Uri) {
      return budget.take(input.toString());
    }
    if (input is Stream) {
      return '<stream>';
    }
    return budget.take(truncateText(input.toString()));
  }

  static Map<String, Object?> _formData(FormData data, _Budget budget) {
    final fields = <String, Object?>{};
    for (final field in data.fields) {
      if (budget.exhausted) {
        fields['<truncated>'] = '<size limit>';
        break;
      }
      fields[field.key] = isSensitiveKey(field.key)
          ? mask
          : budget.take(truncateText(field.value));
    }
    return <String, Object?>{
      'type': 'multipart/form-data',
      'fields': fields,
      'files': data.files.map((entry) => _multipartFile(entry.value)).toList(),
    };
  }

  static Map<String, Object?> _multipartFile(MultipartFile file) {
    return <String, Object?>{
      'filename': file.filename ?? '<unnamed>',
      'contentType': file.contentType?.toString(),
      'size': file.length,
    };
  }

  static String _headerValue(Object? value) {
    if (value is Iterable) {
      return value.map((item) => '$item').join(', ');
    }
    return '$value';
  }

  static String truncateText(String text) {
    final safe = text
        .replaceAll(_bearer, r'$1 ***')
        .replaceAll(_sensitiveText, r'$1***');
    if (safe.length <= maxStringLength) {
      return safe;
    }
    return '${safe.substring(0, maxStringLength)}\n'
        '<truncated: ${safe.length - maxStringLength} characters>';
  }

  /// Best-effort request/response body size, without encoding a whole payload.
  static int? sizeOf(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      return data.length;
    }
    if (data is Uint8List) {
      return data.length;
    }
    if (data is List<int>) {
      return data.length;
    }
    if (data is FormData) {
      var total = 0;
      for (final field in data.fields) {
        total += field.key.length + field.value.length;
      }
      for (final file in data.files) {
        total += file.value.length;
      }
      return total;
    }
    return null;
  }
}

class _Budget {
  _Budget(this._remaining);

  int _remaining;

  bool get exhausted => _remaining <= 0;

  String take(String value) {
    if (value.length <= _remaining) {
      _remaining -= value.length;
      return value;
    }
    final kept = _remaining <= 0 ? '' : value.substring(0, _remaining);
    _remaining = 0;
    return '$kept\n<truncated: log size limit>';
  }
}
