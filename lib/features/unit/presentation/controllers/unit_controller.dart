import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/unit.dart';
import '../../domain/usecases/unit_usecases.dart';

class UnitController extends GetxController {
  UnitController(this.useCases);

  final UnitUseCases useCases;
  final unit = Rxn<Unit>();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadMyUnit();
  }

  Future<void> loadMyUnit() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      unit.value = await useCases.getMyUnit();
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load your unit information.';
    } finally {
      isLoading.value = false;
    }
  }
}
