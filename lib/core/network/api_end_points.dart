/// Every backend path the app uses, in one place.
///
/// Paths that never vary are `static const`. Paths built from an identifier
/// (an invoice id, a reservation code) are static methods, so the caller cannot
/// accidentally interpolate one and forget a slash.
///
/// These mirror the features that already exist in the app. They are grouped by
/// feature and the paths follow the project's own domain names, so a reader can
/// match an endpoint to the screen that needs it. Confirm the concrete paths
/// against the backend before shipping; the structure is what matters here.
abstract final class ApiEndPoints {
  // --- Session -------------------------------------------------------------

  /// Exchanges credentials for an access and refresh token pair.
  static const String login = '/auth/login';

  /// Invalidates the current session token.
  static const String logout = '/auth/logout';

  /// The signed-in resident's own record, used to validate a stored session on
  /// startup.
  static const String me = '/auth/me';

  /// Exchanges a refresh token for a new pair.
  static const String refreshToken = '/auth/refresh';

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

  /// Registers this device's FCM token against the signed-in resident, so the
  /// backend can target it. Paired with [notificationDevice] on sign-out.
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

  /// The resident's own appearance preference, so the chosen brand colour can
  /// follow an account rather than only a device.
  static const String appearance = '/api/profile/appearance';
}
