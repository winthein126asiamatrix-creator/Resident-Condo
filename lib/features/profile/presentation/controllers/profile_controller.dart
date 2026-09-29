import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/resident_role.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/profile_usecases.dart';

class ProfileController extends GetxController {
  ProfileController(this.useCases);

  final ProfileUseCases useCases;
  final profile = Rxn<Profile>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final isLoggedOut = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      profile.value = await useCases.getProfile();
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load your profile.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<Profile?> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? language,
    bool? notificationsEnabled,
  }) async {
    final current = profile.value;
    if (current == null) {
      errorMessage.value = 'Profile information is not available.';
      return null;
    }
    if (name.trim().isEmpty || email.trim().isEmpty || phone.trim().isEmpty) {
      errorMessage.value = 'Name, email, and phone are required.';
      return null;
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.updateProfile(
        current.copyWith(
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          language: language,
          notificationsEnabled: notificationsEnabled,
        ),
      );
      profile.value = updated;
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to update your profile.';
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  void toggleNotifications(bool enabled) {
    final current = profile.value;
    if (current == null) {
      return;
    }
    updateProfile(
      name: current.name,
      email: current.email,
      phone: current.phone,
      language: current.language,
      notificationsEnabled: enabled,
    );
  }

  void logout() {
    isLoggedOut.value = true;
  }

  /// Keeps the profile role label in sync with the active session role.
  Future<Profile?> syncRole(ResidentRole role) async {
    final current = profile.value;
    if (current == null || current.role == role.label) {
      return current;
    }
    return useCases.updateProfile(
      Profile(
        name: current.name,
        email: current.email,
        phone: current.phone,
        unit: current.unit,
        role: role.label,
        initials: current.initials,
        language: current.language,
        notificationsEnabled: current.notificationsEnabled,
      ),
    ).then((updated) {
      profile.value = updated;
      return updated;
    }).catchError((_) => current);
  }

  void restoreSession() {
    isLoggedOut.value = false;
  }
}
