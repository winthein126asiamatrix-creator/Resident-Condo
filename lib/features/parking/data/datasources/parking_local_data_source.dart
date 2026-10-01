import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/parking.dart';

/// In-memory parking records (Odoo would back this with vehicle + space
/// records and the barrier access log).
class ParkingLocalDataSource {
  ParkingLocalDataSource()
    : _spaces = List.of(_initialSpaces),
      _events = List.of(_initialEvents),
      _guestRequests = List.of(_initialGuestRequests);

  final List<ParkingSpace> _spaces;
  final List<ParkingEvent> _events;
  final List<GuestParkingRequest> _guestRequests;

  static const List<ParkingSpace> _initialSpaces = [
    ParkingSpace(
      id: 'space-b2-125',
      slot: 'B2-125',
      level: 'Basement 2',
      type: ParkingSpaceType.allocated,
      status: ParkingStatus.occupied,
      monthlyFee: 45,
      vehicle: 'Toyota Camry',
      licensePlate: 'ABC-1234',
      assignedTo: 'Alex Johnson',
      notes: 'Near the B2 lift lobby.',
    ),
    ParkingSpace(
      id: 'space-b2-126',
      slot: 'B2-126',
      level: 'Basement 2',
      type: ParkingSpaceType.guest,
      status: ParkingStatus.available,
      monthlyFee: 10,
      vehicle: '',
      licensePlate: '',
      assignedTo: 'Guest bay',
    ),
    ParkingSpace(
      id: 'space-b1-041',
      slot: 'B1-041',
      level: 'Basement 1',
      type: ParkingSpaceType.tenant,
      status: ParkingStatus.reserved,
      monthlyFee: 45,
      vehicle: 'Honda Civic',
      licensePlate: 'XYZ-7788',
      assignedTo: 'Jamie Rivera',
    ),
    ParkingSpace(
      id: 'space-b1-042',
      slot: 'B1-042',
      level: 'Basement 1',
      type: ParkingSpaceType.tenant,
      status: ParkingStatus.blocked,
      monthlyFee: 45,
      vehicle: '',
      licensePlate: '',
      assignedTo: 'Maintenance zone',
    ),
  ];

  static const List<ParkingEvent> _initialEvents = [
    ParkingEvent(
      id: 'parking-event-004',
      type: ParkingEventType.entry,
      timestamp: 'Sep 25, 2026 · 8:12 AM',
      plate: 'ABC-1234',
      slot: 'B2-125',
    ),
    ParkingEvent(
      id: 'parking-event-003',
      type: ParkingEventType.exit,
      timestamp: 'Sep 24, 2026 · 7:45 PM',
      plate: 'ABC-1234',
      slot: 'B2-125',
    ),
    ParkingEvent(
      id: 'parking-event-002',
      type: ParkingEventType.entry,
      timestamp: 'Sep 24, 2026 · 9:05 AM',
      plate: 'ABC-1234',
      slot: 'B2-125',
    ),
    ParkingEvent(
      id: 'parking-event-001',
      type: ParkingEventType.exit,
      timestamp: 'Sep 23, 2026 · 6:30 PM',
      plate: 'ABC-1234',
      slot: 'B2-125',
    ),
  ];

  static const List<GuestParkingRequest> _initialGuestRequests = [
    GuestParkingRequest(
      id: 'guest-parking-001',
      guestName: 'Jamie Johnson',
      vehicle: 'Nissan Leaf',
      licensePlate: 'KLM-2210',
      date: 'Sep 25, 2026',
      window: '2:00 PM – 8:00 PM',
      status: 'Approved',
      requestedOn: 'Sep 24, 2026',
    ),
  ];

  Future<List<ParkingSpace>> getSpaces() async => List.unmodifiable(_spaces);

  Future<ParkingSpace?> getMySpace() async {
    for (final space in _spaces) {
      if (space.type == ParkingSpaceType.allocated) {
        return space;
      }
    }
    return null;
  }

  Future<List<ParkingEvent>> getEvents() async => List.unmodifiable(_events);

  Future<List<GuestParkingRequest>> getGuestRequests() async =>
      List.unmodifiable(_guestRequests);

  Future<ParkingSpace> updateVehicle(
    ParkingSpace space,
    String vehicle,
    String plate,
  ) async {
    if (vehicle.trim().isEmpty || plate.trim().isEmpty) {
      throw const AppException('Vehicle model and plate are required.');
    }
    for (final other in _spaces) {
      if (other.id != space.id && other.licensePlate == plate.trim()) {
        throw const AppException('That plate is already registered in the building.');
      }
    }
    final index = _spaces.indexWhere((item) => item.id == space.id);
    if (index == -1) {
      throw const AppException('Parking space could not be found.');
    }
    final updated = _spaces[index].copyWith(
      vehicle: vehicle.trim(),
      licensePlate: plate.trim().toUpperCase(),
      status: ParkingStatus.occupied,
    );
    _spaces[index] = updated;
    return updated;
  }

  Future<GuestParkingRequest> requestGuestParking(
    GuestParkingRequest request,
  ) async {
    if (request.guestName.trim().isEmpty) {
      throw const AppException('Guest name is required.');
    }
    if (request.licensePlate.trim().length < 3) {
      throw const AppException('Enter the guest vehicle plate.');
    }
    final created = GuestParkingRequest(
      id: 'guest-parking-${DateTime.now().microsecondsSinceEpoch}',
      guestName: request.guestName.trim(),
      vehicle: request.vehicle.trim(),
      licensePlate: request.licensePlate.trim().toUpperCase(),
      date: request.date,
      window: request.window,
      status: 'Pending review',
      requestedOn: 'Sep 25, 2026',
      note: request.note,
    );
    _guestRequests.insert(0, created);
    return created;
  }

  Future<GuestParkingRequest> cancelGuestParking(
    GuestParkingRequest request,
  ) async {
    final index = _guestRequests.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      throw const AppException('Guest parking request could not be found.');
    }
    if (_guestRequests[index].status == 'Cancelled') {
      throw const AppException('This request is already cancelled.');
    }
    final updated = GuestParkingRequest(
      id: _guestRequests[index].id,
      guestName: _guestRequests[index].guestName,
      vehicle: _guestRequests[index].vehicle,
      licensePlate: _guestRequests[index].licensePlate,
      date: _guestRequests[index].date,
      window: _guestRequests[index].window,
      status: 'Cancelled',
      requestedOn: _guestRequests[index].requestedOn,
      note: _guestRequests[index].note,
    );
    _guestRequests[index] = updated;
    return updated;
  }
}
