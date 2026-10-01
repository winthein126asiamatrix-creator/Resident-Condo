enum ParkingSpaceType { allocated, tenant, guest, visitor }

extension ParkingSpaceTypeLabel on ParkingSpaceType {
  String get label {
    switch (this) {
      case ParkingSpaceType.allocated:
        return 'Allocated';
      case ParkingSpaceType.tenant:
        return 'Tenant';
      case ParkingSpaceType.guest:
        return 'Guest';
      case ParkingSpaceType.visitor:
        return 'Visitor';
    }
  }
}

enum ParkingStatus { occupied, available, reserved, blocked }

extension ParkingStatusLabel on ParkingStatus {
  String get label {
    switch (this) {
      case ParkingStatus.occupied:
        return 'Occupied';
      case ParkingStatus.available:
        return 'Available';
      case ParkingStatus.reserved:
        return 'Reserved';
      case ParkingStatus.blocked:
        return 'Blocked';
    }
  }
}

class ParkingSpace {
  const ParkingSpace({
    required this.id,
    required this.slot,
    required this.level,
    required this.type,
    required this.status,
    required this.monthlyFee,
    required this.vehicle,
    required this.licensePlate,
    required this.assignedTo,
    this.notes = '',
  });

  final String id;
  final String slot;
  final String level;
  final ParkingSpaceType type;
  final ParkingStatus status;
  final double monthlyFee;
  final String vehicle;
  final String licensePlate;
  final String assignedTo;
  final String notes;

  ParkingSpace copyWith({
    ParkingStatus? status,
    String? vehicle,
    String? licensePlate,
  }) {
    return ParkingSpace(
      id: id,
      slot: slot,
      level: level,
      type: type,
      status: status ?? this.status,
      monthlyFee: monthlyFee,
      vehicle: vehicle ?? this.vehicle,
      licensePlate: licensePlate ?? this.licensePlate,
      assignedTo: assignedTo,
      notes: notes,
    );
  }
}

enum ParkingEventType { entry, exit }

extension ParkingEventTypeLabel on ParkingEventType {
  String get label {
    switch (this) {
      case ParkingEventType.entry:
        return 'Entry';
      case ParkingEventType.exit:
        return 'Exit';
    }
  }
}

class ParkingEvent {
  const ParkingEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.plate,
    required this.slot,
  });

  final String id;
  final ParkingEventType type;
  final String timestamp;
  final String plate;
  final String slot;
}

class GuestParkingRequest {
  const GuestParkingRequest({
    required this.id,
    required this.guestName,
    required this.vehicle,
    required this.licensePlate,
    required this.date,
    required this.window,
    required this.status,
    required this.requestedOn,
    this.note = '',
  });

  final String id;
  final String guestName;
  final String vehicle;
  final String licensePlate;
  final String date;
  final String window;
  final String status;
  final String requestedOn;
  final String note;
}
