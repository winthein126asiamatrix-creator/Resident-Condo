import 'package:get/get.dart';
import 'routes/app_routes.dart';
import '../core/utils/super_print.dart';
import '../features/session/presentation/controllers/session_controller.dart';

String? _pendingInvoiceId;

void setPendingInvoiceId(String id) {
  _pendingInvoiceId = id;
}

String? getPendingInvoiceId() => _pendingInvoiceId;

void clearPendingInvoiceId() {
  _pendingInvoiceId = null;
}

void openPendingInvoiceIfReady() {
  final id = _pendingInvoiceId;
  if (id == null) return;

  if (!Get.isRegistered<SessionController>() ||
      Get.find<SessionController>().session.value == null) {
    return;
  }

  clearPendingInvoiceId();

  superPrint('Opening pending invoice: $id', title: 'Deep Link');

  Get.toNamed<void>(
    AppRoutes.paymentDetail,
    arguments: id,
  );
}
