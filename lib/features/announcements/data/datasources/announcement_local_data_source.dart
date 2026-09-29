import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/announcement.dart';
import '../models/announcement_model.dart';

class AnnouncementLocalDataSource {
  AnnouncementLocalDataSource()
    : _announcements = List<AnnouncementModel>.of(_initialAnnouncements);

  final List<AnnouncementModel> _announcements;

  static final List<AnnouncementModel> _initialAnnouncements = [
    const AnnouncementModel(
      id: 'announcement-001',
      category: AnnouncementCategory.emergency,
      title: 'Elevator 2 maintenance',
      description: 'Elevator 2 in Tower A will be out of service tomorrow from 9–11 AM for its annual safety inspection. Please use Elevator 1 or 3.',
      date: 'Sep 22, 2026',
      isRead: false,
      urgency: AnnouncementUrgency.emergency,
    ),
    const AnnouncementModel(
      id: 'announcement-002',
      category: AnnouncementCategory.community,
      title: 'Rooftop BBQ weekend',
      description: 'Join your neighbours at the rooftop terrace this Saturday from 5 PM. Reserve a pit before Friday through Facilities.',
      date: 'Sep 20, 2026',
      isRead: false,
      urgency: AnnouncementUrgency.important,
    ),
    const AnnouncementModel(
      id: 'announcement-003',
      category: AnnouncementCategory.security,
      title: 'Visitor access codes at the lobby',
      description:
          'Digital visitor passes are now live. Register a visitor and share their alphanumeric access code for a smoother lobby arrival. No QR pass is needed.',
      date: 'Sep 18, 2026',
      isRead: true,
      urgency: AnnouncementUrgency.normal,
    ),
    const AnnouncementModel(
      id: 'announcement-004',
      category: AnnouncementCategory.maintenance,
      title: 'Water shutoff notice',
      description: 'A brief water service interruption is planned for Tower B on Sep 29 from 10 AM to 12 PM.',
      date: 'Sep 16, 2026',
      isRead: true,
      urgency: AnnouncementUrgency.important,
    ),
    const AnnouncementModel(
      id: 'announcement-005',
      category: AnnouncementCategory.general,
      title: 'Updated resident handbook',
      description: 'The updated resident handbook is now available in the portal. Please review the latest community guidelines.',
      date: 'Sep 12, 2026',
      isRead: true,
      urgency: AnnouncementUrgency.normal,
    ),
  ];

  Future<List<AnnouncementModel>> getAnnouncements() async {
    return List<AnnouncementModel>.unmodifiable(_announcements);
  }

  Future<AnnouncementModel> markAsRead(String id) async {
    final index = _announcements.indexWhere(
      (announcement) => announcement.id == id,
    );
    if (index == -1) {
      throw const AppException('Announcement could not be found.');
    }
    _announcements[index] = AnnouncementModel(
      id: _announcements[index].id,
      category: _announcements[index].category,
      title: _announcements[index].title,
      description: _announcements[index].description,
      date: _announcements[index].date,
      isRead: true,
      urgency: _announcements[index].urgency,
    );
    return _announcements[index];
  }
}
