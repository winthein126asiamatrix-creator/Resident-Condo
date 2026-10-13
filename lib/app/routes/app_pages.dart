import 'package:get/get.dart';

import '../../features/announcements/presentation/pages/announcements_page.dart';
import '../../features/appearance/presentation/bindings/appearance_binding.dart';
import '../../features/appearance/presentation/pages/appearance_page.dart';
import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/complaints/domain/entities/complaint.dart';
import '../../features/complaints/presentation/pages/complaint_detail_page.dart';
import '../../features/complaints/presentation/pages/complaints_page.dart';
import '../../features/complaints/presentation/pages/create_complaint_page.dart';
import '../../features/dashboard/presentation/pages/main_shell_page.dart';
import '../../features/facilities/domain/entities/facility.dart';
import '../../features/facilities/presentation/pages/booking_confirmed_page.dart';
import '../../features/facilities/presentation/pages/facility_detail_page.dart';
import '../../features/facilities/presentation/pages/facility_reservation_page.dart';
import '../../features/facilities/presentation/pages/my_reservations_page.dart';
import '../../features/facilities/presentation/pages/reservation_detail_page.dart';
import '../../features/lease/domain/entities/lease.dart';
import '../../features/lease/presentation/pages/lease_page.dart';
import '../../features/lease/presentation/pages/lease_renewal_page.dart';
import '../../features/lease/presentation/pages/lease_renewal_sent_page.dart';
import '../../features/maintenance/domain/entities/maintenance_request.dart';
import '../../features/maintenance/presentation/pages/create_maintenance_request_page.dart';
import '../../features/maintenance/presentation/pages/maintenance_detail_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/parking/presentation/pages/parking_page.dart';
import '../../features/payments/domain/entities/invoice.dart';
import '../../features/payments/domain/entities/payment.dart';
import '../../features/payments/presentation/pages/invoice_detail_page.dart';
import '../../features/payments/presentation/pages/payment_failure_page.dart';
import '../../features/payments/presentation/pages/payment_history_page.dart';
import '../../features/payments/presentation/pages/payment_method_page.dart';
import '../../features/payments/presentation/pages/payment_receipt_page.dart';
import '../../features/payments/presentation/pages/payment_success_page.dart';
import '../../features/payments/presentation/pages/payment_summary_page.dart';
import '../../features/rules/domain/entities/rules.dart';
import '../../features/rules/presentation/pages/appeal_violation_page.dart';
import '../../features/rules/presentation/pages/rule_detail_page.dart';
import '../../features/rules/presentation/pages/rules_page.dart';
import '../../features/rules/presentation/pages/violation_detail_page.dart';
import '../../features/sample/presentation/bindings/sample_binding.dart';
import '../../features/sample/presentation/pages/sample_page.dart';
import '../../features/services/domain/entities/condo_service.dart';
import '../../features/services/presentation/pages/service_request_detail_page.dart';
import '../../features/services/presentation/pages/service_request_page.dart';
import '../../features/services/presentation/pages/services_page.dart';
import '../../features/store/domain/entities/store_product.dart';
import '../../features/store/presentation/bindings/store_binding.dart';
import '../../features/store/presentation/pages/store_checkout_page.dart';
import '../../features/store/presentation/pages/store_order_detail_page.dart';
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/unit/presentation/bindings/unit_binding.dart';
import '../../features/unit/presentation/pages/unit_page.dart';
import '../../features/visitors/domain/entities/visitor.dart';
import '../../features/visitors/presentation/pages/register_visitor_page.dart';
import '../../features/visitors/presentation/pages/visitor_pass_page.dart';
import '../../features/visitors/presentation/pages/visitor_verify_page.dart';
import '../../features/visitors/presentation/pages/visitors_page.dart';
import '../../features/home/presentation/pages/more_services_page.dart';
import '../pages/splash_page.dart';
import '../bindings/app_binding.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: () => SplashPage(),
      // AuthBinding is on both entries: the splash needs it to restore the
      // remembered session, and the home shell needs it for logout. The binding
      // is idempotent, so hitting it twice is safe.
      bindings: [AppBinding(), AuthBinding()],
    ),
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: () => MainShellPage(),
      bindings: [AppBinding(), AuthBinding()],
    ),
    GetPage<dynamic>(
      name: AppRoutes.login,
      page: () => LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(name: AppRoutes.more, page: () => MoreServicesPage()),
    GetPage<dynamic>(name: AppRoutes.notifications, page: () => NotificationsPage()),
    GetPage<dynamic>(name: AppRoutes.announcements, page: () => AnnouncementsPage()),
    GetPage<dynamic>(
      name: AppRoutes.unit,
      page: () => UnitPage(),
      binding: UnitBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentDetail,
      page: () => InvoiceDetailPage(invoice: Get.arguments as Invoice),
    ),
    GetPage<dynamic>(name: AppRoutes.paymentSummary, page: () => PaymentSummaryPage()),
    GetPage<dynamic>(name: AppRoutes.paymentMethod, page: () => PaymentMethodPage()),
    GetPage<dynamic>(
      name: AppRoutes.paymentSuccess,
      page: () => PaymentSuccessPage(payment: Get.arguments as Payment),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentFailure,
      page: () => PaymentFailurePage(payment: Get.arguments as Payment),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentReceipt,
      page: () => PaymentReceiptPage(payment: Get.arguments as Payment),
    ),
    GetPage<dynamic>(name: AppRoutes.paymentHistory, page: () => PaymentHistoryPage()),
    GetPage<dynamic>(
      name: AppRoutes.maintenanceDetail,
      page: () =>
          MaintenanceDetailPage(request: Get.arguments as MaintenanceRequest),
    ),
    GetPage<dynamic>(
      name: AppRoutes.maintenanceCreate,
      page: () => CreateMaintenanceRequestPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.facilityDetail,
      page: () => FacilityDetailPage(facility: Get.arguments as Facility),
    ),
    GetPage<dynamic>(
      name: AppRoutes.facilityReserve,
      page: () => FacilityReservationPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.bookingConfirmed,
      page: () => BookingConfirmedPage(reservation: Get.arguments as FacilityReservation),
    ),
    GetPage<dynamic>(
      name: AppRoutes.myReservations,
      page: () => MyReservationsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.reservationDetail,
      page: () => ReservationDetailPage(reservation: Get.arguments as FacilityReservation),
    ),
    GetPage<dynamic>(name: AppRoutes.lease, page: () => LeasePage()),
    GetPage<dynamic>(name: AppRoutes.leaseRenewal, page: () => LeaseRenewalPage()),
    GetPage<dynamic>(
      name: AppRoutes.leaseRenewalSent,
      page: () => LeaseRenewalSentPage(renewal: Get.arguments as LeaseRenewal),
    ),
    GetPage<dynamic>(name: AppRoutes.visitors, page: () => VisitorsPage()),
    GetPage<dynamic>(name: AppRoutes.visitorRegister, page: () => RegisterVisitorPage()),
    GetPage<dynamic>(
      name: AppRoutes.visitorPass,
      page: () => VisitorPassPage(visitor: Get.arguments as Visitor),
    ),
    GetPage<dynamic>(name: AppRoutes.visitorVerify, page: () => VisitorVerifyPage()),
    GetPage<dynamic>(name: AppRoutes.services, page: () => ServicesPage()),
    GetPage<dynamic>(name: AppRoutes.serviceRequest, page: () => ServiceRequestPage()),
    GetPage<dynamic>(
      name: AppRoutes.serviceRequestDetail,
      page: () => ServiceRequestDetailPage(request: Get.arguments as ServiceRequest),
    ),
    GetPage<dynamic>(name: AppRoutes.parking, page: () => ParkingPage()),
    GetPage<dynamic>(name: AppRoutes.complaints, page: () => ComplaintsPage()),
    GetPage<dynamic>(name: AppRoutes.complaintCreate, page: () => CreateComplaintPage()),
    GetPage<dynamic>(
      name: AppRoutes.complaintDetail,
      page: () => ComplaintDetailPage(complaint: Get.arguments as Complaint),
    ),
    GetPage<dynamic>(name: AppRoutes.rules, page: () => RulesPage()),
    GetPage<dynamic>(
      name: AppRoutes.ruleDetail,
      page: () => RuleDetailPage(rule: Get.arguments as CommunityRule),
    ),
    GetPage<dynamic>(
      name: AppRoutes.violationDetail,
      page: () => ViolationDetailPage(violation: Get.arguments as Violation),
    ),
    GetPage<dynamic>(name: AppRoutes.violationAppeal, page: () => AppealViolationPage()),
    GetPage<dynamic>(
      name: AppRoutes.store,
      page: () => StorePage(),
      binding: StoreBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.storeCheckout,
      page: () => StoreCheckoutPage(),
      binding: StoreBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.storeOrderDetail,
      page: () => StoreOrderDetailPage(order: Get.arguments as StoreOrder),
      binding: StoreBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.appearance,
      page: () => AppearancePage(),
      binding: AppearanceBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.sample,
      page: () => SamplePage(),
      binding: SampleBinding(),
    ),
  ];
}
