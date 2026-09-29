import '../../domain/entities/announcement.dart';

class AnnouncementModel extends Announcement {
  const AnnouncementModel({
    required super.id,
    required super.category,
    required super.title,
    required super.description,
    required super.date,
    required super.isRead,
    required super.urgency,
  });
}
