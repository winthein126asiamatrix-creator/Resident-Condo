import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/sample.dart';
import '../../domain/usecases/sample_usecases.dart';

class SampleController extends GetxController {
  SampleController(this.useCases);

  final SampleUseCases useCases;
  final samples = <Sample>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadSamples();
  }

  Future<void> loadSamples() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      samples.assignAll(await useCases.getSamples());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load samples.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addSample({
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) {
      errorMessage.value = 'Title is required.';
      return;
    }
    await _runMutation(
      () => useCases.addSample(
        Sample(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.trim(),
          description: description.trim(),
          isActive: true,
        ),
      ),
    );
  }

  Future<void> updateSample({
    required Sample sample,
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) {
      errorMessage.value = 'Title is required.';
      return;
    }
    await _runMutation(
      () => useCases.updateSample(
        sample.copyWith(title: title.trim(), description: description.trim()),
      ),
    );
  }

  Future<void> deleteSample(String id) {
    return _runMutation(() => useCases.deleteSample(id));
  }

  Future<void> toggleSample(String id) {
    return _runMutation(() => useCases.toggleSample(id));
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await action();
      samples.assignAll(await useCases.getSamples());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to complete the operation.';
    } finally {
      isLoading.value = false;
    }
  }
}
