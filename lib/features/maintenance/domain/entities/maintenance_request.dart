import '../../../../core/utils/app_dates.dart';

enum MaintenanceCategory {
  plumbing,
  electrical,
  airConditioning,
  elevator,
  commonArea,
  internet,
  other;

  static MaintenanceCategory fromCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    return switch (normalized) {
      'plumbing' => MaintenanceCategory.plumbing,
      'electrical' || 'electric' => MaintenanceCategory.electrical,
      'airconditioning' ||
      'aircon' ||
      'hvac' => MaintenanceCategory.airConditioning,
      'elevator' || 'lift' => MaintenanceCategory.elevator,
      'commonarea' || 'common' => MaintenanceCategory.commonArea,
      'internet' || 'network' || 'wifi' => MaintenanceCategory.internet,
      _ => MaintenanceCategory.other,
    };
  }

  String get defaultCode {
    switch (this) {
      case MaintenanceCategory.plumbing:
        return 'plumbing';
      case MaintenanceCategory.electrical:
        return 'electrical';
      case MaintenanceCategory.airConditioning:
        return 'air_conditioning';
      case MaintenanceCategory.elevator:
        return 'elevator';
      case MaintenanceCategory.commonArea:
        return 'common_area';
      case MaintenanceCategory.internet:
        return 'internet';
      case MaintenanceCategory.other:
        return 'other';
    }
  }
}

extension MaintenanceCategoryLabel on MaintenanceCategory {
  String get label {
    switch (this) {
      case MaintenanceCategory.plumbing:
        return 'Plumbing';
      case MaintenanceCategory.electrical:
        return 'Electrical';
      case MaintenanceCategory.airConditioning:
        return 'Air Conditioning';
      case MaintenanceCategory.elevator:
        return 'Elevator';
      case MaintenanceCategory.commonArea:
        return 'Common Area';
      case MaintenanceCategory.internet:
        return 'Internet';
      case MaintenanceCategory.other:
        return 'Other';
    }
  }
}

enum MaintenancePriority {
  low,
  medium,
  high;

  static MaintenancePriority fromApi(Object? value) {
    final normalized = (value ?? '').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return switch (normalized) {
      'low' || 'minor' || '1' => MaintenancePriority.low,
      'high' || 'urgent' || 'critical' || '3' => MaintenancePriority.high,
      _ => MaintenancePriority.medium,
    };
  }

  String get apiValue {
    switch (this) {
      case MaintenancePriority.low:
        return 'low';
      case MaintenancePriority.medium:
        return 'medium';
      case MaintenancePriority.high:
        return 'high';
    }
  }
}

extension MaintenancePriorityLabel on MaintenancePriority {
  String get label {
    switch (this) {
      case MaintenancePriority.low:
        return 'Low priority';
      case MaintenancePriority.medium:
        return 'Medium priority';
      case MaintenancePriority.high:
        return 'High priority';
    }
  }
}

enum MaintenanceStatus {
  submitted,
  assigned,
  inProgress,
  completed,
  cancelled;

  static MaintenanceStatus fromApi(Object? value) {
    final normalized = (value ?? '').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return switch (normalized) {
      'submitted' ||
      'pending' ||
      'open' ||
      'requested' => MaintenanceStatus.submitted,
      'assigned' || 'accepted' => MaintenanceStatus.assigned,
      'in_progress' ||
      'inprogress' ||
      'ongoing' ||
      'started' => MaintenanceStatus.inProgress,
      'completed' || 'done' || 'resolved' => MaintenanceStatus.completed,
      'cancelled' || 'canceled' || 'rejected' => MaintenanceStatus.cancelled,
      _ => MaintenanceStatus.submitted,
    };
  }

  String get apiValue {
    switch (this) {
      case MaintenanceStatus.submitted:
        return 'submitted';
      case MaintenanceStatus.assigned:
        return 'assigned';
      case MaintenanceStatus.inProgress:
        return 'in_progress';
      case MaintenanceStatus.completed:
        return 'completed';
      case MaintenanceStatus.cancelled:
        return 'cancelled';
    }
  }
}

extension MaintenanceStatusLabel on MaintenanceStatus {
  String get label {
    switch (this) {
      case MaintenanceStatus.submitted:
        return 'Requested';
      case MaintenanceStatus.assigned:
        return 'Assigned';
      case MaintenanceStatus.inProgress:
        return 'In Progress';
      case MaintenanceStatus.completed:
        return 'Completed';
      case MaintenanceStatus.cancelled:
        return 'Cancelled';
    }
  }

  MaintenanceStatus? get next {
    switch (this) {
      case MaintenanceStatus.submitted:
        return MaintenanceStatus.assigned;
      case MaintenanceStatus.assigned:
        return MaintenanceStatus.inProgress;
      case MaintenanceStatus.inProgress:
        return MaintenanceStatus.completed;
      case MaintenanceStatus.completed:
      case MaintenanceStatus.cancelled:
        return null;
    }
  }
}

class MaintenanceCategoryOption {
  const MaintenanceCategoryOption({
    this.id,
    required this.code,
    required this.label,
    this.isActive = true,
  });

  final int? id;
  final String code;
  final String label;
  final bool isActive;

  factory MaintenanceCategoryOption.fromJson(Map<String, dynamic> json) {
    return MaintenanceCategoryOption(
      id: _asInt(json['id']),
      code: (json['code'] ?? json['name'] ?? '').toString().trim(),
      label: (json['label'] ?? json['name'] ?? json['code'] ?? '')
          .toString()
          .trim(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'label': label,
    'is_active': isActive,
  };
}

class MaintenancePhoto {
  const MaintenancePhoto({
    required this.id,
    required this.url,
    this.caption = '',
    this.createdAt,
  });

  final String id;
  final String url;
  final String caption;
  final String? createdAt;

  factory MaintenancePhoto.fromJson(Map<String, dynamic> json) {
    final url =
        json['url'] ??
        json['file_url'] ??
        json['photo_url'] ??
        json['image_url'] ??
        '';
    return MaintenancePhoto(
      id: (json['id'] ?? json['uuid'] ?? '').toString(),
      url: url.toString(),
      caption:
          (json['caption'] ??
                  json['name'] ??
                  json['filename'] ??
                  json['file_name'] ??
                  '')
              .toString(),
      createdAt: (json['created_at'] ?? json['uploaded_at'] ?? json['date'])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'url': url,
    'caption': caption,
    if (createdAt != null) 'created_at': createdAt,
  };
}

class MaintenanceProgressEntry {
  const MaintenanceProgressEntry({
    required this.status,
    this.statusLabel,
    this.note,
    this.actor,
    this.createdAt,
  });

  final MaintenanceStatus status;
  final String? statusLabel;
  final String? note;
  final String? actor;
  final String? createdAt;

  String get displayLabel =>
      (statusLabel == null || statusLabel!.trim().isEmpty)
      ? status.label
      : statusLabel!;

  /// The moment this progress entry happened, ready to show beside its status.
  ///
  /// Returns `null` when the backend did not send a timestamp or it cannot be
  /// parsed, so the caller can omit the subtitle instead of showing a
  /// misleading one.
  String? get occurredAtDisplay => _formatTimestamp(createdAt);

  factory MaintenanceProgressEntry.fromJson(Map<String, dynamic> json) {
    return MaintenanceProgressEntry(
      status: MaintenanceStatus.fromApi(json['status']),
      statusLabel: (json['status_label'] ?? json['label'] ?? json['title'])
          ?.toString(),
      note:
          (json['note'] ??
                  json['comment'] ??
                  json['message'] ??
                  json['description'])
              ?.toString(),
      actor: (json['actor'] ?? json['by'] ?? json['user'] ?? json['technician'])
          ?.toString(),
      createdAt:
          (json['at'] ??
                  json['created_at'] ??
                  json['occurred_at'] ??
                  json['timestamp'] ??
                  json['date'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.apiValue,
    if (statusLabel != null) 'status_label': statusLabel,
    if (note != null) 'note': note,
    if (actor != null) 'actor': actor,
    if (createdAt != null) 'created_at': createdAt,
  };
}

class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    this.reference = '',
    required this.title,
    required this.categoryCode,
    required this.categoryLabel,
    required this.description,
    required this.location,
    this.unit = '',
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.preferredDate,
    required this.preferredTime,
    this.photoCount = 0,
    this.technician,
    this.assignedAt,
    this.inProgressAt,
    this.completedAt,
    this.cancelledAt,
    this.timezone = 'UTC',
    this.photos = const <MaintenancePhoto>[],
    this.progressHistory = const <MaintenanceProgressEntry>[],
  });

  final String id;
  final String reference;
  final String title;
  final String categoryCode;
  final String categoryLabel;
  final String description;
  final String location;
  final String unit;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final String createdAt;
  final String preferredDate;
  final String preferredTime;
  final int photoCount;
  final String? technician;
  final String? assignedAt;
  final String? inProgressAt;
  final String? completedAt;
  final String? cancelledAt;
  final String timezone;
  final List<MaintenancePhoto> photos;
  final List<MaintenanceProgressEntry> progressHistory;

  MaintenanceCategory get category => MaintenanceCategory.fromCode(
    categoryCode.isNotEmpty ? categoryCode : categoryLabel,
  );

  String get categoryDisplay =>
      categoryLabel.trim().isEmpty ? category.label : categoryLabel;

  int get resolvedPhotoCount => photos.isNotEmpty ? photos.length : photoCount;

  /// Submission date and time from the backend `created_at` value.
  ///
  /// Returns an empty string when the value is missing or cannot be parsed so
  /// the caller can fall back without showing a misleading timestamp.
  String get createdAtDisplay => _formatTimestamp(createdAt) ?? '';

  /// The date and time the backend recorded for [status].
  ///
  /// List responses carry the `*_at` workflow fields without a progress
  /// history, so the timeline uses this as a fallback. Returns `null` when the
  /// field is missing or cannot be parsed.
  String? statusTimestampDisplay(MaintenanceStatus status) {
    final value = switch (status) {
      MaintenanceStatus.submitted => createdAt,
      MaintenanceStatus.assigned => assignedAt,
      MaintenanceStatus.inProgress => inProgressAt,
      MaintenanceStatus.completed => completedAt,
      MaintenanceStatus.cancelled => cancelledAt,
    };
    return _formatTimestamp(value);
  }

  String get preferredDateDisplay => _formatDate(preferredDate);

  String get preferredTimeDisplay => _formatTime(preferredTime);

  String? get completedAtDisplay =>
      completedAt == null ? null : _formatDate(completedAt!);

  String? get cancelledAtDisplay =>
      cancelledAt == null ? null : _formatDate(cancelledAt!);

  bool get canCancel =>
      status == MaintenanceStatus.submitted ||
      status == MaintenanceStatus.assigned;

  MaintenanceRequest copyWith({
    String? id,
    String? reference,
    String? title,
    String? categoryCode,
    String? categoryLabel,
    String? description,
    String? location,
    String? unit,
    MaintenancePriority? priority,
    MaintenanceStatus? status,
    String? createdAt,
    String? preferredDate,
    String? preferredTime,
    int? photoCount,
    String? technician,
    String? assignedAt,
    String? inProgressAt,
    String? completedAt,
    String? cancelledAt,
    String? timezone,
    List<MaintenancePhoto>? photos,
    List<MaintenanceProgressEntry>? progressHistory,
  }) {
    return MaintenanceRequest(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      title: title ?? this.title,
      categoryCode: categoryCode ?? this.categoryCode,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      description: description ?? this.description,
      location: location ?? this.location,
      unit: unit ?? this.unit,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTime: preferredTime ?? this.preferredTime,
      photoCount: photoCount ?? this.photoCount,
      technician: technician ?? this.technician,
      assignedAt: assignedAt ?? this.assignedAt,
      inProgressAt: inProgressAt ?? this.inProgressAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      timezone: timezone ?? this.timezone,
      photos: photos ?? this.photos,
      progressHistory: progressHistory ?? this.progressHistory,
    );
  }
}

class MaintenancePhotoUpload {
  const MaintenancePhotoUpload({
    required this.path,
    required this.name,
    this.mimeType,
  });

  final String path;
  final String name;
  final String? mimeType;
}

class MaintenancePageResult {
  const MaintenancePageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<MaintenanceRequest> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  static const MaintenancePageResult empty = MaintenancePageResult(
    items: <MaintenanceRequest>[],
    page: 1,
    limit: 20,
    total: 0,
  );

  factory MaintenancePageResult.fromJson(
    Object? json, {
    int fallbackPage = 1,
    int fallbackLimit = 20,
  }) {
    if (json is List) {
      final items = json
          .whereType<Map>()
          .map((item) => _requestFromMap(Map<String, dynamic>.from(item)))
          .toList();
      return MaintenancePageResult(
        items: items,
        page: fallbackPage,
        limit: fallbackLimit,
        total: (fallbackPage - 1) * fallbackLimit + items.length,
      );
    }
    var map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    while (map['data'] is Map &&
        map['items'] == null &&
        map['requests'] == null) {
      final nested = Map<String, dynamic>.from(map['data'] as Map);
      map.remove('data');
      map.addAll(nested);
    }
    final rawItems = map['items'] ?? map['requests'] ?? map['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => _requestFromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <MaintenanceRequest>[];
    final page = _asInt(map['page']) ?? fallbackPage;
    final limit =
        _asInt(map['limit']) ?? (items.isEmpty ? fallbackLimit : items.length);
    final total = _asInt(map['total']) ?? (page - 1) * limit + items.length;
    return MaintenancePageResult(
      items: items,
      page: page,
      limit: limit,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'items': items.map((item) => _requestToMap(item)).toList(),
    'page': page,
    'limit': limit,
    'total': total,
  };
}

class MaintenanceSummary {
  const MaintenanceSummary({
    this.totalRequests = 0,
    this.submittedCount = 0,
    this.assignedCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
  });

  final int totalRequests;
  final int submittedCount;
  final int assignedCount;
  final int inProgressCount;
  final int completedCount;

  factory MaintenanceSummary.fromJson(Object? json) {
    var map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    while (map['data'] is Map || map['summary'] is Map) {
      final key = map['data'] is Map ? 'data' : 'summary';
      final nested = Map<String, dynamic>.from(map[key] as Map);
      map.remove(key);
      map.addAll(nested);
    }
    return MaintenanceSummary(
      totalRequests: _asInt(map['total_requests']) ?? 0,
      submittedCount: _asInt(map['submitted_count']) ?? 0,
      assignedCount: _asInt(map['assigned_count']) ?? 0,
      inProgressCount: _asInt(map['in_progress_count']) ?? 0,
      completedCount: _asInt(map['completed_count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total_requests': totalRequests,
    'submitted_count': submittedCount,
    'assigned_count': assignedCount,
    'in_progress_count': inProgressCount,
    'completed_count': completedCount,
  };
}

class MaintenanceCancellation {
  const MaintenanceCancellation({
    required this.id,
    this.reference = '',
    this.status = MaintenanceStatus.cancelled,
    this.cancelledAt,
    this.message = '',
  });

  final String id;
  final String reference;
  final MaintenanceStatus status;
  final String? cancelledAt;
  final String message;

  factory MaintenanceCancellation.fromJson(
    Object? json, {
    String fallbackId = '',
  }) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    return MaintenanceCancellation(
      id: (map['id'] ?? fallbackId).toString(),
      reference: (map['reference'] ?? '').toString(),
      status: MaintenanceStatus.fromApi(map['status']),
      cancelledAt: (map['cancelled_at'] ?? map['cancelledAt'])?.toString(),
      message: (map['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'reference': reference,
    'status': status.apiValue,
    if (cancelledAt != null) 'cancelled_at': cancelledAt,
    'message': message,
  };
}

MaintenanceRequest _requestFromMap(Map<String, dynamic> json) {
  return MaintenanceRequestModelData.fromJson(json);
}

Map<String, dynamic> _requestToMap(MaintenanceRequest request) {
  return MaintenanceRequestModelData.toJson(request);
}

class MaintenanceRequestModelData {
  const MaintenanceRequestModelData._();

  static MaintenanceRequest fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    Map<String, dynamic>? categoryMap;
    if (categoryJson is Map) {
      categoryMap = Map<String, dynamic>.from(categoryJson);
    }
    final categoryCode =
        (categoryMap?['code'] ??
                categoryMap?['name'] ??
                (categoryJson is String ? categoryJson : null) ??
                json['category_code'] ??
                '')
            .toString()
            .trim();
    final categoryLabel =
        (categoryMap?['label'] ??
                categoryMap?['name'] ??
                json['category_label'] ??
                '')
            .toString()
            .trim();

    final photosJson = json['photos'];
    final photos = photosJson is List
        ? photosJson
              .whereType<Map>()
              .map(
                (item) =>
                    MaintenancePhoto.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <MaintenancePhoto>[];

    final progressJson =
        json['progress_history'] ?? json['progress'] ?? json['history'];
    final progress = progressJson is List
        ? progressJson
              .whereType<Map>()
              .map(
                (item) => MaintenanceProgressEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <MaintenanceProgressEntry>[];

    final technicianJson = json['technician'];
    String? technician;
    if (technicianJson is String) {
      technician = technicianJson.trim().isEmpty ? null : technicianJson.trim();
    } else if (technicianJson is Map) {
      technician =
          (technicianJson['name'] ??
                  technicianJson['display_name'] ??
                  technicianJson['label'])
              ?.toString();
    }

    final unitJson = json['unit'];
    final unit = unitJson is Map
        ? (unitJson['label'] ??
                  unitJson['name'] ??
                  unitJson['code'] ??
                  unitJson['number'] ??
                  '')
              .toString()
        : (unitJson ?? json['unit_label'] ?? '').toString();

    final photoCount =
        _asInt(json['photo_count']) ?? (photos.isNotEmpty ? photos.length : 0);

    return MaintenanceRequest(
      id: (json['id'] ?? json['uuid'] ?? '').toString(),
      reference: (json['reference'] ?? json['code'] ?? '').toString(),
      title: (json['title'] ?? json['subject'] ?? json['name'] ?? '')
          .toString(),
      categoryCode: categoryCode,
      categoryLabel: categoryLabel.isEmpty
          ? MaintenanceCategory.fromCode(categoryCode).label
          : categoryLabel,
      description: (json['description'] ?? json['details'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      unit: unit,
      priority: MaintenancePriority.fromApi(
        json['priority'] ?? json['priority_label'],
      ),
      status: MaintenanceStatus.fromApi(json['status']),
      createdAt:
          (json['created_at'] ??
                  json['createdAt'] ??
                  json['requested_on'] ??
                  '')
              .toString(),
      preferredDate:
          (json['preferred_date'] ??
                  json['preferredDate'] ??
                  json['scheduled_date'] ??
                  '')
              .toString(),
      preferredTime:
          (json['preferred_time'] ??
                  json['preferredTime'] ??
                  json['scheduled_time'] ??
                  '')
              .toString(),
      photoCount: photoCount,
      technician: technician,
      assignedAt: (json['assigned_at'] ?? json['assignedAt'])?.toString(),
      inProgressAt: (json['in_progress_at'] ?? json['inProgressAt'])
          ?.toString(),
      completedAt: (json['completed_at'] ?? json['completedAt'])?.toString(),
      cancelledAt: (json['cancelled_at'] ?? json['cancelledAt'])?.toString(),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      photos: photos,
      progressHistory: progress,
    );
  }

  static Map<String, dynamic> toJson(MaintenanceRequest request) {
    return <String, dynamic>{
      'id': request.id,
      'reference': request.reference,
      'title': request.title,
      'category': <String, dynamic>{
        'code': request.categoryCode,
        'label': request.categoryLabel,
      },
      'description': request.description,
      'location': request.location,
      'unit': request.unit,
      'priority': request.priority.apiValue,
      'status': request.status.apiValue,
      'created_at': request.createdAt,
      'preferred_date': request.preferredDate,
      'preferred_time': request.preferredTime,
      'photo_count': request.photoCount,
      if (request.technician != null) 'technician': request.technician,
      if (request.assignedAt != null) 'assigned_at': request.assignedAt,
      if (request.inProgressAt != null) 'in_progress_at': request.inProgressAt,
      if (request.completedAt != null) 'completed_at': request.completedAt,
      if (request.cancelledAt != null) 'cancelled_at': request.cancelledAt,
      'timezone': request.timezone,
      'photos': request.photos.map((photo) => photo.toJson()).toList(),
      'progress_history': request.progressHistory
          .map((entry) => entry.toJson())
          .toList(),
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

String _formatDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return AppDates.format(parsed);
  return text;
}

/// Formats a backend timestamp (`Nov 25, 2026 · 2:39 PM`).
///
/// Returns `null` for missing or unparseable values so no timestamp is shown.
String? _formatTimestamp(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  final hasTime = RegExp(r'\d{1,2}:\d{2}').hasMatch(text);
  return hasTime ? AppDates.formatDateTime(local) : AppDates.format(local);
}

String _formatTime(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (match == null) return text;
  final hour = int.tryParse(match.group(1)!) ?? 0;
  final minute = match.group(2)!;
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute $period';
}
