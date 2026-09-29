enum AnnouncementCategory {
  maintenance,
  security,
  community,
  emergency,
  general,
}

extension AnnouncementCategoryLabel on AnnouncementCategory {
  String get label {
    switch (this) {
      case AnnouncementCategory.maintenance:
        return 'Maintenance';
      case AnnouncementCategory.security:
        return 'Security';
      case AnnouncementCategory.community:
        return 'Community';
      case AnnouncementCategory.emergency:
        return 'Emergency';
      case AnnouncementCategory.general:
        return 'General';
    }
  }
}

enum AnnouncementUrgency { normal, important, emergency }

extension AnnouncementUrgencyLabel on AnnouncementUrgency {
  String get label {
    switch (this) {
      case AnnouncementUrgency.normal:
        return 'General';
      case AnnouncementUrgency.important:
        return 'Important';
      case AnnouncementUrgency.emergency:
        return 'Urgent';
    }
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.date,
    required this.isRead,
    required this.urgency,
  });

  final String id;
  final AnnouncementCategory category;
  final String title;
  final String description;
  final String date;
  final bool isRead;
  final AnnouncementUrgency urgency;

  Announcement copyWith({bool? isRead}) {
    return Announcement(
      id: id,
      category: category,
      title: title,
      description: description,
      date: date,
      isRead: isRead ?? this.isRead,
      urgency: urgency,
    );
  }
}
