import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 28 underscores: the divider width this log format was written against.
final String _divider = '_ ' * 28;

/// Pretty prints a value to the debug console, with the caller and a timestamp.
///
/// Intended for the one-off "what just happened" note during development: a tap,
/// a state change, an unexpected branch. Nothing is printed in a release build,
/// and no dependency is added.
///
/// Maps and Lists are printed as indented JSON so a payload is readable rather
/// than collapsed onto one line; anything else falls back to its own description.
/// Values that cannot be encoded are described instead of throwing, because a
/// log call must never be the thing that breaks the app.
///
/// ```dart
/// superPrint('Login button clicked');
/// superPrint(
///   {'username': 'emilys', 'status': 'success'},
///   title: 'Login Result',
/// );
/// superPrint({'isLoading': true}, title: 'Auth Controller');
/// ```
void superPrint(dynamic content, {dynamic title = 'Super Print'}) {
  if (!kDebugMode) {
    return;
  }

  debugPrint(
    '- $title\n'
    '${_caller()}\n'
    '$_divider\n'
    '${_format(content)}\n'
    '$_divider ${_timestamp()}',
    wrapWidth: 1024,
  );
}

/// The location that called [superPrint], as `lib/path/to/file.dart:42:10`.
///
/// Every frame from this utility is skipped, so the location belongs to the
/// caller's own file rather than `super_print.dart`. The `package:` URI is
/// rewritten to a path relative to the project root, which is what the VS Code
/// Debug Console resolves into a clickable link.
String _caller() {
  final frames = StackTrace.current.toString().split('\n');
  for (final frame in frames) {
    if (frame.contains('super_print.dart')) {
      continue;
    }
    final location = _locationOf(frame);
    if (location != null) {
      return location;
    }
  }
  return 'unknown';
}

/// Extracts `lib/path/to/file.dart:42:10` from a stack frame.
///
/// A frame looks like `#2  signIn (package:test/lib/foo.dart:42:10)`. The
/// location inside the parentheses is rewritten from a `package:` URI to a
/// path relative to the project root, which is what the editor can open.
String? _locationOf(String frame) {
  final match = RegExp(r'\(([^)]+)\)').firstMatch(frame);
  if (match == null) {
    return null;
  }
  final location = match.group(1)!;
  if (!location.startsWith('package:test/')) {
    return location;
  }
  return location.replaceFirst('package:test/', 'lib/');
}

/// The message body: indented JSON for Maps and Lists, a description otherwise.
String _format(Object? content) {
  if (content is Map || content is List) {
    try {
      return JsonEncoder.withIndent('  ').convert(content);
    } catch (_) {
      // A Map or List can still hold something JSON cannot encode. Describe it
      // rather than failing the log call.
      return content.toString();
    }
  }
  return content.toString();
}

/// `13 : 2 : 5.123`: hour, minute, then second.millisecond.
String _timestamp() {
  final now = DateTime.now();
  final ms = now.millisecond.toString().padLeft(3, '0');
  return '${now.hour} : ${now.minute} : ${now.second}.$ms';
}
