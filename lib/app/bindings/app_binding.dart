import 'package:get/get.dart';

import '../../features/announcements/presentation/bindings/announcement_binding.dart';
import '../../features/complaints/presentation/bindings/complaint_binding.dart';
import '../../features/dashboard/presentation/bindings/dashboard_binding.dart';
import '../../features/facilities/presentation/bindings/facility_binding.dart';
import '../../features/lease/presentation/bindings/lease_binding.dart';
import '../../features/maintenance/presentation/bindings/maintenance_binding.dart';
import '../../features/notifications/presentation/bindings/notification_binding.dart';
import '../../features/parking/presentation/bindings/parking_binding.dart';
import '../../features/payments/presentation/bindings/payment_binding.dart';
import '../../features/profile/presentation/bindings/profile_binding.dart';
import '../../features/rules/presentation/bindings/rules_binding.dart';
import '../../features/services/presentation/bindings/condo_service_binding.dart';
import '../../features/session/presentation/bindings/session_binding.dart';
import '../../features/visitors/presentation/bindings/visitor_binding.dart';

/// Registers every app-scoped feature dependency in one place.
///
/// The feature controllers are session scoped: they hold the in-memory mock
/// data for the signed-in resident. They must survive route transitions such as
/// `Get.offNamed` / `Get.offAllNamed`, otherwise a still mounted page can call
/// `Get.find` for a controller that was deleted together with a previous
/// `/home` instance ("...Controller not found").
///
/// Every feature binding below registers its controller with `permanent: true`,
/// so running this binding again is safe and simply keeps the existing
/// instances.
class AppBinding extends Bindings {
  @override
  void dependencies() {
    final bindings = <Bindings>[
      SessionBinding(),
      DashboardBinding(),
      PaymentBinding(),
      MaintenanceBinding(),
      FacilityBinding(),
      ProfileBinding(),
      AnnouncementBinding(),
      NotificationBinding(),
      LeaseBinding(),
      VisitorBinding(),
      CondoServiceBinding(),
      ParkingBinding(),
      ComplaintBinding(),
      RulesBinding(),
    ];
    for (final binding in bindings) {
      binding.dependencies();
    }
  }
}
