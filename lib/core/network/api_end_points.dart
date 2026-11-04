abstract final class ApiEndPoints {
  // --- Session -------------------------------------------------------------

  static const String login = '/auth/login';

  static const String logout = '/auth/logout';

  /// The signed-in resident. GET loads the profile; PATCH updates name, phone
  /// and email.
  static const String me = '/me';

  static const String avatar = '$me/avatar';

  static const String refreshToken = '/auth/refresh';

  static const String changePassword = '/auth/change-password';

  // --- Resident unit -------------------------------------------------------

  static const String units = '/api/units';
  static const String unitOccupants = '/api/units/occupants';

  /// One unit by id.
  static String unit(int id) => '/api/units/$id';

  // --- Payments ------------------------------------------------------------

  static const String invoices = '/api/invoices';
  static const String payments = '/api/payments';

  /// A payment method already on file.
  static const String paymentMethods = '/api/payments/methods';

  /// One invoice, with its line items.
  static String invoice(String reference) => '/api/invoices/$reference';

  /// Pays one or more selected invoice lines.
  static const String payInvoice = '/api/invoices/pay';

  /// Issues a receipt for a completed payment.
  static String receipt(String reference) => '/api/payments/$reference/receipt';

  // --- Maintenance ---------------------------------------------------------

  static const String maintenanceRequests = '/api/maintenance/requests';
  static const String maintenanceCategories = '/api/maintenance/categories';

  /// One request, with its progress timeline.
  static String maintenanceRequest(int id) => '/api/maintenance/requests/$id';

  /// Photos attached to a request, uploaded as multipart.
  static String maintenancePhotos(int id) =>
      '/api/maintenance/requests/$id/photos';

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
  //
  // PROVISIONAL. The backend has no notification API yet, so these paths and
  // the payload around them are a proposal, not a description of something that
  // exists. They are gathered here rather than inlined in the data source so
  // that confirming them with the backend team is a change to one file.

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

  static const String lease = '/api/lease';
  static const String leaseRenewals = '/api/lease/renewals';

  static String leaseRenewal(int id) => '/api/lease/renewals/$id';

  // --- Convenience store ---------------------------------------------------

  static const String storeProducts = '/api/store/products';
  static const String storeOrders = '/api/store/orders';

  static String storeOrder(String reference) => '/api/store/orders/$reference';

  // --- Resident profile ----------------------------------------------------

  static const String profile = '/api/profile';

  static const String appearance = '/api/profile/appearance';
}
