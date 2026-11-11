import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/datasources/payment_dashboard_local_data_source.dart';
import '../../data/datasources/payment_dashboard_remote_data_source.dart';
import '../../data/datasources/payment_invoice_local_data_source.dart';
import '../../data/datasources/payment_invoice_remote_data_source.dart';
import '../../data/datasources/payment_list_local_data_source.dart';
import '../../data/datasources/payment_local_data_source.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/usecases/payment_usecases.dart';
import '../controllers/payment_controller.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PaymentDashboardRemoteDataSource>()) {
      Get.put<PaymentDashboardRemoteDataSource>(
        PaymentDashboardRemoteDataSource(Get.find<DioApiService>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentDashboardLocalDataSource>()) {
      Get.put<PaymentDashboardLocalDataSource>(
        PaymentDashboardLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
          // The dashboard is personal, so the device copy is scoped to the
          // resident who fetched it.
          accountKey: _currentAccountKey,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentInvoiceRemoteDataSource>()) {
      Get.put<PaymentInvoiceRemoteDataSource>(
        PaymentInvoiceRemoteDataSource(Get.find<DioApiService>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentInvoiceLocalDataSource>()) {
      Get.put<PaymentInvoiceLocalDataSource>(
        PaymentInvoiceLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
          accountKey: _currentAccountKey,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentListLocalDataSource>()) {
      Get.put<PaymentListLocalDataSource>(
        PaymentListLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
          accountKey: _currentAccountKey,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentRepository>()) {
      Get.put<PaymentRepository>(
        PaymentRepositoryImpl(
          PaymentLocalDataSource(),
          Get.find<PaymentDashboardRemoteDataSource>(),
          Get.find<PaymentDashboardLocalDataSource>(),
          invoiceDataSource: Get.find<PaymentInvoiceRemoteDataSource>(),
          invoiceLocalDataSource: Get.find<PaymentInvoiceLocalDataSource>(),
          paymentListLocalDataSource: Get.find<PaymentListLocalDataSource>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentUseCases>()) {
      Get.put<PaymentUseCases>(
        PaymentUseCases(Get.find<PaymentRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentController>()) {
      Get.put<PaymentController>(
        PaymentController(Get.find<PaymentUseCases>()),
        permanent: true,
      );
    }
  }

  /// The resident whose dashboard the cache belongs to, or null when signed out.
  static String? _currentAccountKey() {
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }
    final user = Get.find<SessionController>().currentUser;
    if (user == null || user.id <= 0) {
      return null;
    }
    return 'user:${user.id}';
  }
}
