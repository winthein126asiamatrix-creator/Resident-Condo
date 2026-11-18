abstract final class ApiEndPoints {
  // --- Configuration -------------------------------------------------------

  static const String appConfig = '/app/config';
  static const String condoConfig = '/condo/config';

  // --- Session -------------------------------------------------------------

  static const String login = '/auth/login';

  static const String logout = '/auth/logout';

  /// The signed-in resident. GET loads the profile; PATCH updates name, phone
  /// and email.
  static const String me = '/me';

  /// The signed-in resident's appearance and notification preferences.
  ///
  /// A partial update: each request carries only the field being changed.
  static const String preferences = '$me/preferences';

  static const String avatar = '$me/avatar';

  static const String refreshToken = '/auth/refresh';

  static const String changePassword = '/auth/change-password';

  // --- Resident unit -------------------------------------------------------

  static const String units = '/api/units';
  static const String unitOccupants = '/api/units/occupants';

  /// One unit by id.
  static String unit(int id) => '/api/units/$id';

  // --- Payments ------------------------------------------------------------

  /// The resident's invoice list, newest first.
  static const String invoices = '/payments/invoices';

  /// One invoice with its unit and line items.
  static String invoiceDetail(int id) => '$invoices/$id';

  static const String payments = '/payments';

  /// Submits a payment for one or more selected invoice lines.
  static const String payment = '/payment';

  /// Prices the selected invoice lines before the payment is submitted.
  static const String paymentQuote = '$payments/quote';

  static String paymentDetail(int id) => '$payments/$id';

  /// The resident's payment dashboard: balance, fee breakdown, invoice counts
  /// and recent activity.
  static const String paymentDashboard = '/payments/dashboard';

  /// The payment methods residents can choose from.
  static const String paymentMethods = '/payments/methods';

  /// One invoice, with its line items.
  static String invoice(Object reference) => '$invoices/$reference';

  // --- Maintenance ---------------------------------------------------------

  static const String maintenanceRequests = '/maintenance/requests';
  static const String maintenanceCategories = '/maintenance/categories';

  static String maintenanceRequest(Object id) => '/maintenance/requests/$id';

  static String maintenancePhotos(Object id) =>
      '/maintenance/requests/$id/photos';

  static const String maintenanceSummary = '/maintenance/summary';

  static String maintenanceCancel(Object id) =>
      '/maintenance/requests/$id/cancel';

  // --- Facilities ----------------------------------------------------------

  static const String facilities = '/api/facilities';
  static const String facilityReservations = '/api/facilities/reservations';
  static const String facilityAvailability = '/api/facilities/availability';

  static String facility(int id) => '/api/facilities/$id';

  static String facilityReservationsFor(int facilityId) =>
      '/api/facilities/$facilityId/reservations';

  static String facilityReservation(String reference) =>
      '/api/facilities/reservations/$reference';

  // --- Visitors ------------------------------------------------------------

  static const String visitors = '/api/visitors';

  /// Pre-registering a visitor, then confirming their arrival.
  static String visitorCheckIn(int id) => '/api/visitors/$id/check-in';

  static String visitorCheckOut(int id) => '/api/visitors/$id/check-out';

  /// The pass shown to the visitor, by its public code.
  static String visitorPass(String code) => '/api/visitors/pass/$code';

  // --- Parking -------------------------------------------------------------

  static const String parkingSpaces = '/api/parking/spaces';
  static const String parkingMySpace = '/api/parking/my-space';
  static const String parkingRequests = '/api/parking/requests';

  static String parkingSpaceEvents(int spaceId) =>
      '/api/parking/spaces/$spaceId/events';

  // --- Complaints ----------------------------------------------------------

  static const String complaints = '/api/complaints';

  static String complaint(int id) => '/api/complaints/$id';

  /// Photos attached to a complaint.
  static String complaintPhotos(int id) => '/api/complaints/$id/photos';

  // --- Announcements and notifications -------------------------------------

  static const String announcements = '/api/announcements';
  static const String notifications = '/api/notifications';

  static String announcement(int id) => '/api/announcements/$id';

  static String notificationRead(String id) => '/api/notifications/$id/read';

  /// How many notifications the resident has not read.
  ///
  /// Separate from the list so the bell can be correct without downloading the
  /// whole history on every app resume.
  static const String notificationUnreadCount =
      '/api/notifications/unread-count';

  /// Marks every unread notification as read in one call.
  static const String notificationReadAll = '/api/notifications/read-all';

  static const String notificationDevices = '/api/notifications/devices';

  static String notificationDevice(String token) =>
      '/api/notifications/devices/${Uri.encodeComponent(token)}';

  // --- Lease ---------------------------------------------------------------

  static const String lease = '/lease';
  static const String leaseRenewals = '/lease/renewals';

  static String leaseRenewal(Object id) =>
      '/lease/renewals/${Uri.encodeComponent('$id')}';

  // --- Convenience store ---------------------------------------------------

  static const String storeProducts = '/api/store/products';
  static const String storeOrders = '/api/store/orders';

  static String storeOrder(String reference) => '/api/store/orders/$reference';

  // --- Resident profile ----------------------------------------------------

  static const String profile = '/api/profile';

  // --- Condo services -----------------------------------------------------

  static const String services = '/services';

  static String service(int id) => '/services/$id';

  static const String serviceRequests = '/service-requests';

  static String serviceRequestCancel(Object id) =>
      '/service-requests/${Uri.encodeComponent('$id')}/cancel';

  static const String appearance = '/api/profile/appearance';

  // --- My Unit -------------------------------------------------------------

  static const String myUnit = '/my-unit';
}
