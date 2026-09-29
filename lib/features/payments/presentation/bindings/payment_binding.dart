import 'package:get/get.dart';

import '../../data/datasources/payment_local_data_source.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/usecases/payment_usecases.dart';
import '../controllers/payment_controller.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<PaymentRepository>(
      PaymentRepositoryImpl(PaymentLocalDataSource()),
      permanent: true,
    );
    Get.put<PaymentUseCases>(
      PaymentUseCases(Get.find<PaymentRepository>()),
      permanent: true,
    );
    Get.put<PaymentController>(
      PaymentController(Get.find<PaymentUseCases>()),
      permanent: true,
    );
  }
}
