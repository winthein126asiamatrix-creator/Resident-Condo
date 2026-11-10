import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../models/payment_dashboard_model.dart';

/// Loads the resident's payment dashboard from the shared API client.
class PaymentDashboardRemoteDataSource {
  const PaymentDashboardRemoteDataSource(this._service);

  final DioApiService _service;

  Future<PaymentDashboardModel> getDashboard() {
    return _service.get<PaymentDashboardModel>(
      ApiEndPoints.paymentDashboard,
      parse: PaymentDashboardModel.parse,
    );
  }
}
