enum MaintenanceCategory {
  plumbing,
  electrical,
  airConditioning,
  elevator,
  commonArea,
  internet,
  other,
}

enum MaintenancePriority { low, medium, high }

enum MaintenanceStatus { submitted, assigned, inProgress, completed }

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

extension MaintenanceStatusLabel on MaintenanceStatus {
  String get label {
    switch (this) {
      case MaintenanceStatus.submitted:
        return 'Submitted';
      case MaintenanceStatus.assigned:
        return 'Assigned';
      case MaintenanceStatus.inProgress:
        return 'In Progress';
      case MaintenanceStatus.completed:
        return 'Completed';
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
        return null;
    }
  }
}

class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.preferredDate,
    required this.preferredTime,
    required this.photoNames,
    this.technician,
  });

  final String id;
  final String title;
  final MaintenanceCategory category;
  final String description;
  final String location;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final String createdAt;
  final String preferredDate;
  final String preferredTime;
  final List<String> photoNames;
  final String? technician;

  int get photoCount => photoNames.length;

  MaintenanceRequest copyWith({MaintenanceStatus? status, String? technician}) {
    return MaintenanceRequest(
      id: id,
      title: title,
      category: category,
      description: description,
      location: location,
      priority: priority,
      status: status ?? this.status,
      createdAt: createdAt,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      photoNames: photoNames,
      technician: technician ?? this.technician,
    );
  }
}
