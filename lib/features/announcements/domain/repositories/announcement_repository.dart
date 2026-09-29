import '../../domain/entities/announcement.dart';

abstract interface class AnnouncementRepository {
  Future<List<Announcement>> getAnnouncements();

  Future<Announcement> markAsRead(String id);
}
