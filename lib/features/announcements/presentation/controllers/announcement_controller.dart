import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/usecases/announcement_usecases.dart';

class AnnouncementController extends GetxController {
  AnnouncementController(this.useCases);

  final AnnouncementUseCases useCases;
  final announcements = <Announcement>[].obs;
  final selectedCategory = Rxn<AnnouncementCategory>();
  final isLoading = false.obs;
  final isUpdating = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadAnnouncements();
  }

  int get unreadCount =>
      announcements.where((announcement) => !announcement.isRead).length;

  List<Announcement> get visibleAnnouncements {
    final category = selectedCategory.value;
    if (category == null) {
      return announcements;
    }
    return announcements
        .where((announcement) => announcement.category == category)
        .toList();
  }

  Future<void> loadAnnouncements() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      announcements.assignAll(await useCases.getAnnouncements());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load announcements.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectCategory(AnnouncementCategory? category) {
    selectedCategory.value = category;
  }

  Future<void> markAsRead(Announcement announcement) async {
    if (announcement.isRead) {
      return;
    }
    isUpdating.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.markAsRead(announcement.id);
      final index = announcements.indexWhere(
        (item) => item.id == announcement.id,
      );
      if (index != -1) {
        announcements[index] = updated;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to update the announcement.';
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    if (unreadCount == 0) {
      return;
    }
    isUpdating.value = true;
    errorMessage.value = null;
    try {
      for (final announcement in announcements.where((item) => !item.isRead)) {
        await markAsRead(announcement);
      }
    } finally {
      isUpdating.value = false;
    }
  }
}
