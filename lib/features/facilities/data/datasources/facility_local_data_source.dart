import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/facility.dart';
import '../models/facility_model.dart';

class FacilityLocalDataSource {
  FacilityLocalDataSource()
    : _facilities = List<FacilityModel>.of(_initialFacilities),
      _reservations = List<FacilityReservationModel>.of(_seedReservations());

  final List<FacilityModel> _facilities;
  final List<FacilityReservationModel> _reservations;

  static final List<FacilityModel> _initialFacilities = [
    const FacilityModel(
      id: 'facility-gym',
      name: 'Fitness Centre',
      imagePath: 'assets/images/amenities/gym.jpg',
      location: 'Level 3 · Tower A',
      description: 'A bright, fully equipped fitness centre with cardio, strength and functional training zones.',
      rules: 'Please wear indoor shoes and wipe down equipment after use.',
      openingHours: '6:00 AM – 10:00 PM',
      capacity: 24,
      availableSlots: ['6:00 PM', '7:00 PM', '8:00 PM'],
    ),
    const FacilityModel(
      id: 'facility-pool',
      name: 'Swimming Pool',
      imagePath: 'assets/images/amenities/swimming_pool.jpg',
      location: 'Rooftop · Tower A',
      description: 'A temperature-controlled pool with a quiet lounge and sunset views over the city.',
      rules: 'Children must be accompanied by an adult. No glass containers.',
      openingHours: '7:00 AM – 9:00 PM',
      capacity: 18,
      availableSlots: ['9:00 AM', '11:00 AM', '4:00 PM'],
    ),
    const FacilityModel(
      id: 'facility-function',
      name: 'Function Room',
      imagePath: 'assets/images/amenities/function_room.jpg',
      location: 'Level 1 · Clubhouse',
      description: 'A flexible event space for private celebrations and community gatherings.',
      rules:
          'Bookings are limited to four hours. Leave the room clean after use.',
      openingHours: '9:00 AM – 11:00 PM',
      capacity: 60,
      availableSlots: ['2:00 PM', '6:00 PM'],
    ),
    const FacilityModel(
      id: 'facility-meeting',
      name: 'Meeting Room',
      imagePath: 'assets/images/amenities/meeting_room.jpg',
      location: 'Level 2 · Tower A',
      description: 'A quiet, professional room for resident meetings and small working groups.',
      rules: 'Please keep the room tidy and avoid bookings over three hours.',
      openingHours: '8:00 AM – 9:00 PM',
      capacity: 12,
      availableSlots: ['10:00 AM', '1:00 PM', '5:00 PM'],
    ),
    const FacilityModel(
      id: 'facility-bbq',
      name: 'Rooftop BBQ',
      imagePath: 'assets/images/amenities/bbq_area.jpg',
      location: 'Rooftop · Tower B',
      description: 'A communal terrace with grills and covered seating for relaxed gatherings.',
      rules: 'One grill per group. Please clean your area after use.',
      openingHours: '11:00 AM – 11:00 PM',
      capacity: 20,
      availableSlots: ['5:00 PM', '7:00 PM'],
    ),
    const FacilityModel(
      id: 'facility-tennis',
      name: 'Tennis Court',
      imagePath: 'assets/images/amenities/tennis_court.jpg',
      location: 'Garden Level · Tower B',
      description: 'A reservable outdoor court for singles or doubles matches.',
      rules: 'Court use is limited to 60 minutes. Proper tennis shoes are required.',
      openingHours: '7:00 AM – 9:00 PM',
      capacity: 4,
      availableSlots: ['8:00 AM', '10:00 AM', '6:00 PM'],
    ),
  ];

  /// Seeded relative to today so the list always has something upcoming and
  /// something past to show. A real backend would return these from storage.
  static List<FacilityReservationModel> _seedReservations() {
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    return [
      FacilityReservationModel(
        id: 'RES-001',
        facilityId: 'facility-gym',
        facilityName: 'Fitness Centre',
        date: AppDates.format(day(-4)),
        time: '6:00 PM',
        status: 'Completed',
        createdAt: AppDates.format(day(-6)),
      ),
      FacilityReservationModel(
        id: 'RES-002',
        facilityId: 'facility-bbq',
        facilityName: 'Rooftop BBQ',
        date: AppDates.format(day(3)),
        time: '5:00 PM',
        status: 'Confirmed',
        createdAt: AppDates.format(day(-1)),
      ),
    ];
  }

  Future<List<FacilityModel>> getFacilities() async {
    return List<FacilityModel>.unmodifiable(_facilities);
  }

  Future<FacilityModel?> getFacility(String id) async {
    for (final facility in _facilities) {
      if (facility.id == id) {
        return facility;
      }
    }
    return null;
  }

  Future<List<FacilityReservationModel>> getReservations() async {
    return List<FacilityReservationModel>.unmodifiable(_reservations);
  }

  Future<FacilityReservationModel> createReservation(
    FacilityReservation reservation,
  ) async {
    final facilityIndex = _facilities.indexWhere(
      (facility) => facility.id == reservation.facilityId,
    );
    if (facilityIndex == -1) {
      throw const AppException('Facility could not be found.');
    }
    final facility = _facilities[facilityIndex];
    // A custom time is the resident's own choice, so it is accepted as is. A
    // predefined slot still has to be free.
    if (!reservation.isCustomTime &&
        !facility.availableSlots.contains(reservation.time)) {
      throw const AppException('That time slot is no longer available.');
    }
    final updatedSlots = reservation.isCustomTime
        ? facility.availableSlots
        : facility.availableSlots
              .where((slot) => slot != reservation.time)
              .toList();
    _facilities[facilityIndex] = FacilityModel(
      id: facility.id,
      name: facility.name,
      imagePath: facility.imagePath,
      location: facility.location,
      description: facility.description,
      rules: facility.rules,
      openingHours: facility.openingHours,
      capacity: facility.capacity,
      availableSlots: updatedSlots,
    );
    final created = FacilityReservationModel(
      // The data source plays the backend's part here and hands out the
      // reference, the way an Odoo / API create call would. Anything the caller
      // sent as an id is ignored for the same reason.
      id: _nextReservationId(),
      facilityId: reservation.facilityId,
      facilityName: reservation.facilityName,
      date: reservation.date,
      time: reservation.time,
      status: 'Confirmed',
      createdAt: reservation.createdAt,
      isCustomTime: reservation.isCustomTime,
    );
    _reservations.insert(0, created);
    return created;
  }

  String _nextReservationId() {
    var highest = 0;
    for (final reservation in _reservations) {
      final number = int.tryParse(
        reservation.id.replaceFirst(RegExp(r'^[A-Za-z-]+'), ''),
      );
      if (number != null && number > highest) {
        highest = number;
      }
    }
    return 'RES-${(highest + 1).toString().padLeft(3, '0')}';
  }
}
