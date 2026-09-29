import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement_local_data_source.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  const AnnouncementRepositoryImpl(this.localDataSource);

  final AnnouncementLocalDataSource localDataSource;

  @override
  Future<List<Announcement>> getAnnouncements() async {
    final announcements = await localDataSource.getAnnouncements();
    return List<Announcement>.of(announcements);
  }

  @override
  Future<Announcement> markAsRead(String id) {
    return localDataSource.markAsRead(id);
  }
}
