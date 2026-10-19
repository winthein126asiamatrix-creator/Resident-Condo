import '../../domain/entities/notification_item.dart';

class NotificationItemModel extends NotificationItem {
  const NotificationItemModel({
    required super.id,
    required super.type,
    required super.title,
    required super.message,
    required super.period,
    required super.isRead,
  });

  /// Builds a model from the provisional backend payload.
  ///
  /// Every field is read defensively because the contract in `ApiEndPoints` has
  /// not been confirmed with the backend team: a missing or wrongly typed field
  /// yields a usable notification rather than failing the whole list. A record
  /// with no usable id at all is rejected by returning null, because an id is
  /// what mark-as-read and de-duplication both rely on.
  static NotificationItemModel? fromWire(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = _idOf(json);
    if (id == null || id.isEmpty) {
      return null;
    }
    final createdAt = _dateOf(json['created_at']);
    return NotificationItemModel(
      id: id,
      type:
          NotificationTypeWire.fromWire(json['type']) ??
          NotificationType.unknown,
      title: _textOf(json['title'], fallback: 'Update'),
      message: _textOf(json['message'] ?? json['body']),
      // The backend may group by period already; when it does not, the date the
      // notification was created decides, which is the same rule the seed data
      // was written by hand against.
      period: _periodOf(json['period']) ?? _periodFromDate(createdAt),
      isRead: _flagOf(json['is_read'] ?? json['read']) ?? false,
    );
  }

  /// The cached shape written by [toCacheJson].
  ///
  /// Stored rather than the raw response so a later build can read its own
  /// cache after the wire format changes.
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'period': period.name,
    'is_read': isRead,
  };

  static NotificationItemModel? fromCacheJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return NotificationItemModel(
      id: id,
      type:
          NotificationTypeWire.fromWire(json['type']) ??
          NotificationType.unknown,
      title: _textOf(json['title'], fallback: 'Update'),
      message: _textOf(json['message']),
      period: _periodOf(json['period']) ?? NotificationPeriod.today,
      isRead: json['is_read'] == true,
    );
  }

  @override
  NotificationItemModel copyWith({bool? isRead}) => NotificationItemModel(
    id: id,
    type: type,
    title: title,
    message: message,
    period: period,
    isRead: isRead ?? this.isRead,
  );

  static String? _idOf(Map<dynamic, dynamic> json) {
    final raw = json['id'];
    if (raw == null) {
      return null;
    }
    return raw.toString();
  }

  static String _textOf(Object? raw, {String fallback = ''}) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static bool? _flagOf(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final value = raw?.toString().toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
    return null;
  }

  static DateTime? _dateOf(Object? raw) {
    if (raw is DateTime) {
      return raw;
    }
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  static NotificationPeriod? _periodOf(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    for (final period in NotificationPeriod.values) {
      if (period.name == value) {
        return period;
      }
    }
    return null;
  }

  /// Today, yesterday, or earlier, from when the notification was created.
  ///
  /// Local time on purpose: "today" is the resident's day, not the server's, and
  /// the list groups by [NotificationPeriod].
  static NotificationPeriod _periodFromDate(DateTime? date) {
    if (date == null) {
      return NotificationPeriod.today;
    }
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference <= 0) {
      return NotificationPeriod.today;
    }
    if (difference == 1) {
      return NotificationPeriod.yesterday;
    }
    return NotificationPeriod.earlier;
  }
}
