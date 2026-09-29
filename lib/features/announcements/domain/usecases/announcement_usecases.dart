import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

class AnnouncementUseCases {
  const AnnouncementUseCases(this.repository);

  final AnnouncementRepository repository;

  Future<List<Announcement>> getAnnouncements() {
    return repository.getAnnouncements();
  }

  Future<Announcement> markAsRead(String id) {
    return repository.markAsRead(id);
  }
}
