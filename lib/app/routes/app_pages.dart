import 'package:get/get.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_page.dart';

import '../../features/announcements/presentation/pages/announcements_page.dart';
import '../../features/appearance/presentation/bindings/appearance_binding.dart';
import '../../features/appearance/presentation/pages/appearance_page.dart';
import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/complaints/domain/entities/complaint.dart';
import '../../features/complaints/presentation/pages/complaint_detail_page.dart';
import '../../features/complaints/presentation/pages/complaints_page.dart';
import '../../features/complaints/presentation/pages/create_complaint_page.dart';
import '../../features/config/domain/entities/condo_config.dart';
import '../../features/config/presentation/middlewares/feature_gate_middleware.dart';
import '../../features/config/presentation/middlewares/update_gate_middleware.dart';
import '../../features/config/presentation/pages/app_update_screen.dart';
import '../../features/config/presentation/pages/feature_unavailable_page.dart';
import '../../features/dashboard/presentation/pages/main_shell_page.dart';
import '../../features/dev_tools/presentation/pages/api_log_viewer_page.dart';
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
import '../../features/payments/presentation/pages/invoice_list_page.dart';
import '../../features/payments/presentation/pages/invoice_selection_page.dart';
import '../../features/payments/presentation/pages/payment_details_page.dart';
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
import '../../features/services/presentation/bindings/condo_service_binding.dart';
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
  static final _rawPages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: () => SplashPage(),
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
    GetPage<dynamic>(
      name: AppRoutes.notifications,
      page: () => NotificationsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.announcements,
      page: () => AnnouncementsPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.unit,
      page: () => UnitPage(),
      binding: UnitBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.invoiceList,
      page: () => const InvoiceListPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.payments)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.invoiceSelection,
      page: () => const InvoiceSelectionPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.payments)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentDetail,
      page: () {
        final arguments = Get.arguments;
        if (arguments is int) {
          return InvoiceDetailPage(invoiceId: arguments);
        }
        if (arguments is Invoice) {
          return InvoiceDetailPage(invoice: arguments);
        }
        return const InvoiceDetailPage();
      },
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentSummary,
      page: () => PaymentSummaryPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentMethod,
      page: () => PaymentMethodPage(),
    ),
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
    GetPage<dynamic>(
      name: AppRoutes.paymentHistory,
      page: () => PaymentHistoryPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.payments)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.paymentDetails,
      page: () {
        final arguments = Get.arguments;
        final id = arguments is int
            ? arguments
            : arguments is num
            ? arguments.toInt()
            : null;
        return PaymentDetailsPage(paymentId: id);
      },
    ),
    GetPage<dynamic>(
      name: AppRoutes.maintenance,
      page: () => MaintenancePage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.maintenance)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.maintenanceDetail,
      page: () =>
          MaintenanceDetailPage(request: Get.arguments as MaintenanceRequest),
      middlewares: [FeatureGateMiddleware(CondoFeature.maintenance)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.maintenanceCreate,
      page: () => CreateMaintenanceRequestPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.maintenance)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.facilityDetail,
      page: () => FacilityDetailPage(facility: Get.arguments as Facility),
      middlewares: [FeatureGateMiddleware(CondoFeature.facilities)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.facilityReserve,
      page: () => FacilityReservationPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.facilities)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.bookingConfirmed,
      page: () => BookingConfirmedPage(
        reservation: Get.arguments as FacilityReservation,
      ),
      middlewares: [FeatureGateMiddleware(CondoFeature.facilities)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.myReservations,
      page: () => MyReservationsPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.facilities)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.reservationDetail,
      page: () => ReservationDetailPage(
        reservation: Get.arguments as FacilityReservation,
      ),
      middlewares: [FeatureGateMiddleware(CondoFeature.facilities)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.lease,
      page: () => LeasePage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.lease)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.leaseRenewal,
      page: () => LeaseRenewalPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.lease)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.leaseRenewalSent,
      page: () => LeaseRenewalSentPage(renewal: Get.arguments as LeaseRenewal),
      middlewares: [FeatureGateMiddleware(CondoFeature.lease)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.visitors,
      page: () => VisitorsPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.visitors)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.visitorRegister,
      page: () => RegisterVisitorPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.visitors)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.visitorPass,
      page: () => VisitorPassPage(visitor: Get.arguments as Visitor),
      middlewares: [FeatureGateMiddleware(CondoFeature.visitors)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.visitorVerify,
      page: () => VisitorVerifyPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.visitors)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.services,
      page: () => ServicesPage(),
      binding: CondoServiceBinding(),
      middlewares: [FeatureGateMiddleware(CondoFeature.condoServices)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.serviceRequest,
      page: () => ServiceRequestPage(),
      binding: CondoServiceBinding(),
      middlewares: [FeatureGateMiddleware(CondoFeature.condoServices)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.serviceRequestDetail,
      page: () =>
          ServiceRequestDetailPage(request: Get.arguments as ServiceRequest),
      middlewares: [FeatureGateMiddleware(CondoFeature.condoServices)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.parking,
      page: () => ParkingPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.parking)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.complaints,
      page: () => ComplaintsPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.complaints)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.complaintCreate,
      page: () => CreateComplaintPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.complaints)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.complaintDetail,
      page: () => ComplaintDetailPage(complaint: Get.arguments as Complaint),
      middlewares: [FeatureGateMiddleware(CondoFeature.complaints)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.rules,
      page: () => RulesPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.rulesViolations)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.ruleDetail,
      page: () => RuleDetailPage(rule: Get.arguments as CommunityRule),
      middlewares: [FeatureGateMiddleware(CondoFeature.rulesViolations)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.violationDetail,
      page: () => ViolationDetailPage(violation: Get.arguments as Violation),
      middlewares: [FeatureGateMiddleware(CondoFeature.rulesViolations)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.violationAppeal,
      page: () => AppealViolationPage(),
      middlewares: [FeatureGateMiddleware(CondoFeature.violationAppeals)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.store,
      page: () => StorePage(),
      binding: StoreBinding(),
      middlewares: [FeatureGateMiddleware(CondoFeature.convenienceStore)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.storeCheckout,
      page: () => StoreCheckoutPage(),
      binding: StoreBinding(),
      middlewares: [FeatureGateMiddleware(CondoFeature.convenienceStore)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.storeOrderDetail,
      page: () => StoreOrderDetailPage(order: Get.arguments as StoreOrder),
      binding: StoreBinding(),
      middlewares: [FeatureGateMiddleware(CondoFeature.convenienceStore)],
    ),
    GetPage<dynamic>(
      name: AppRoutes.appearance,
      page: () => AppearancePage(),
      binding: AppearanceBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.featureUnavailable,
      page: () => const FeatureUnavailablePage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.appUpdate,
      page: () => const AppUpdateRoute(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.sample,
      page: () => SamplePage(),
      binding: SampleBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.apiLogs,
      page: () => const ApiLogViewerPage(),
    ),
  ];

  static final pages = _guardedPages(_rawPages);

  static List<GetPage<dynamic>> _guardedPages(List<GetPage<dynamic>> pages) =>
      pages.map(_guardPage).toList();

  static GetPage<dynamic> _guardPage(GetPage<dynamic> page) {
    if (page.name == AppRoutes.appUpdate) return page;
    return GetPage<dynamic>(
      name: page.name,
      page: page.page,
      binding: page.binding,
      bindings: page.bindings,
      middlewares: <GetMiddleware>[
        UpdateGateMiddleware(),
        ...?page.middlewares,
      ],
    );
  }
}
