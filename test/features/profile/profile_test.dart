import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:test/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:test/features/profile/domain/repositories/profile_repository.dart';
import 'package:test/features/profile/domain/usecases/profile_usecases.dart';
import 'package:test/features/profile/presentation/bindings/profile_binding.dart';
import 'package:test/features/profile/presentation/controllers/profile_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads the mock resident profile', () async {
    final repository = ProfileRepositoryImpl(ProfileLocalDataSource());
    final controller = ProfileController(ProfileUseCases(repository));

    await controller.loadProfile();

    expect(controller.profile.value?.name, 'Alex Johnson');
    expect(controller.profile.value?.role, 'Owner');
    expect(controller.profile.value?.unit, 'Tower A · 1205');
  });

  test('updates profile fields locally', () async {
    final repository = ProfileRepositoryImpl(ProfileLocalDataSource());
    final controller = ProfileController(ProfileUseCases(repository));
    await controller.loadProfile();

    final updated = await controller.updateProfile(
      name: 'Alex Johnson Updated',
      email: 'alex.updated@example.com',
      phone: '+959772611100',
    );

    expect(updated, isNotNull);
    expect(controller.profile.value?.name, 'Alex Johnson Updated');
    expect(controller.profile.value?.email, 'alex.updated@example.com');
    expect(controller.profile.value?.phone, '+1 555 014 2027');
  });

  test('binding provides the profile dependency graph', () {
    ProfileBinding().dependencies();

    expect(Get.find<ProfileRepository>(), isA<ProfileRepositoryImpl>());
    expect(Get.find<ProfileUseCases>(), isA<ProfileUseCases>());
    expect(Get.find<ProfileController>(), isA<ProfileController>());
    expect(
      Get.find<ProfileController>().useCases.repository,
      isA<ProfileRepositoryImpl>(),
    );
  });
}
