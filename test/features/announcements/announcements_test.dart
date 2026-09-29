import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/announcements/data/datasources/announcement_local_data_source.dart';
import 'package:test/features/announcements/data/repositories/announcement_repository_impl.dart';
import 'package:test/features/announcements/domain/entities/announcement.dart';
import 'package:test/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:test/features/announcements/domain/usecases/announcement_usecases.dart';
import 'package:test/features/announcements/presentation/bindings/announcement_binding.dart';
import 'package:test/features/announcements/presentation/controllers/announcement_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads announcements and filters by category', () async {
    final repository = AnnouncementRepositoryImpl(
      AnnouncementLocalDataSource(),
    );
    final controller = AnnouncementController(AnnouncementUseCases(repository));

    await controller.loadAnnouncements();

    expect(controller.announcements, hasLength(5));
    expect(controller.unreadCount, 2);

    controller.selectCategory(AnnouncementCategory.security);
    expect(controller.visibleAnnouncements, hasLength(1));
    expect(
      controller.visibleAnnouncements.single.title,
      'Visitor access codes at the lobby',
    );
  });

  test('marks announcements as read locally', () async {
    final repository = AnnouncementRepositoryImpl(
      AnnouncementLocalDataSource(),
    );
    final controller = AnnouncementController(AnnouncementUseCases(repository));
    await controller.loadAnnouncements();

    final unread = controller.announcements.firstWhere(
      (announcement) => !announcement.isRead,
    );
    await controller.markAsRead(unread);
    expect(controller.unreadCount, 1);

    await controller.markAllAsRead();
    expect(controller.unreadCount, 0);
  });

  test('binding provides the announcement dependency graph', () {
    AnnouncementBinding().dependencies();

    expect(
      Get.find<AnnouncementRepository>(),
      isA<AnnouncementRepositoryImpl>(),
    );
    expect(Get.find<AnnouncementUseCases>(), isA<AnnouncementUseCases>());
    expect(Get.find<AnnouncementController>(), isA<AnnouncementController>());
    expect(
      Get.find<AnnouncementController>().useCases.repository,
      isA<AnnouncementRepositoryImpl>(),
    );
  });
}
