import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/visitor.dart';
import '../../domain/utils/visitor_code.dart';
import '../models/visitor_model.dart';

class VisitorLocalDataSource {
  VisitorLocalDataSource()
    : _visitors = List<VisitorModel>.of(_initialVisitors);

  final List<VisitorModel> _visitors;

  static final List<VisitorModel> _initialVisitors = [
    const VisitorModel(
      id: 'visitor-001',
      name: 'Jamie Johnson',
      phone: '+1 555 018 2244',
      relation: VisitorRelation.family,
      purpose: 'Family dinner',
      date: 'Sep 25, 2026',
      arrivalWindow: '2:00 PM – 4:00 PM',
      status: VisitorStatus.preRegistered,
      accessCode: 'VIS K7M-4QX',
      registeredBy: 'Alex Johnson',
      registeredOn: 'Sep 24, 2026',
      notes: 'Parking in the guest bay on level 1.',
    ),
    const VisitorModel(
      id: 'visitor-002',
      name: 'Marco Diaz',
      phone: '+1 555 019 7731',
      relation: VisitorRelation.serviceProvider,
      purpose: 'Aircon maintenance visit',
      date: 'Sep 25, 2026',
      arrivalWindow: '10:00 AM – 12:00 PM',
      status: VisitorStatus.checkedIn,
      accessCode: 'VIS P4T-9WB',
      registeredBy: 'Alex Johnson',
      registeredOn: 'Sep 23, 2026',
      vehiclePlate: 'XYZ-7788',
      checkedInAt: '10:04 AM',
    ),
    const VisitorModel(
      id: 'visitor-003',
      name: 'Sofia Chen',
      phone: '+1 555 011 9025',
      relation: VisitorRelation.friend,
      purpose: 'Weekend visit',
      date: 'Sep 22, 2026',
      arrivalWindow: '11:00 AM – 8:00 PM',
      status: VisitorStatus.checkedOut,
      accessCode: 'VIS H2R-6TN',
      registeredBy: 'Alex Johnson',
      registeredOn: 'Sep 20, 2026',
      checkedInAt: '11:06 AM',
      checkedOutAt: '7:42 PM',
    ),
    const VisitorModel(
      id: 'visitor-004',
      name: 'Rider · BoxNow',
      phone: '+1 555 013 3320',
      relation: VisitorRelation.delivery,
      purpose: 'Parcel delivery',
      date: 'Sep 21, 2026',
      arrivalWindow: '9:00 AM – 5:00 PM',
      status: VisitorStatus.checkedOut,
      accessCode: 'VIS D8V-3KM',
      registeredBy: 'Alex Johnson',
      registeredOn: 'Sep 21, 2026',
      vehiclePlate: 'BOX-118',
      checkedInAt: '1:20 PM',
      checkedOutAt: '1:35 PM',
    ),
  ];

  Future<List<VisitorModel>> getVisitors() async {
    return List<VisitorModel>.unmodifiable(_visitors);
  }

  Future<VisitorModel?> getVisitor(String id) async {
    for (final visitor in _visitors) {
      if (visitor.id == id) {
        return visitor;
      }
    }
    return null;
  }

  Future<VisitorModel?> findByAccessCode(String code) async {
    final normalized = VisitorCodeGenerator.normalize(code);
    if (normalized.length < 7) {
      return null;
    }
    for (final visitor in _visitors) {
      if (visitor.accessCode == normalized) {
        return visitor;
      }
    }
    return null;
  }

  Future<VisitorModel> registerVisitor(Visitor visitor) async {
    if (visitor.name.trim().isEmpty) {
      throw const AppException('Visitor name is required.');
    }
    if (visitor.phone.trim().length < 6) {
      throw const AppException('Enter a contact number for the visitor.');
    }
    var code = visitor.accessCode;
    if (code.isEmpty || await findByAccessCode(code) != null) {
      code = await _uniqueCode();
    }
    final created = VisitorModel(
      id: 'visitor-${DateTime.now().microsecondsSinceEpoch}',
      name: visitor.name.trim(),
      phone: visitor.phone.trim(),
      relation: visitor.relation,
      purpose: visitor.purpose,
      date: visitor.date,
      arrivalWindow: visitor.arrivalWindow,
      status: VisitorStatus.preRegistered,
      accessCode: code,
      registeredBy: visitor.registeredBy,
      registeredOn: visitor.registeredOn,
      vehiclePlate: visitor.vehiclePlate,
      notes: visitor.notes,
    );
    _visitors.insert(0, created);
    return created;
  }

  Future<VisitorModel> checkIn(Visitor visitor) async {
    return _apply(visitor, VisitorStatus.checkedIn, '10:04 AM');
  }

  Future<VisitorModel> checkOut(Visitor visitor) async {
    return _apply(visitor, VisitorStatus.checkedOut, '3:18 PM');
  }

  Future<VisitorModel> cancelVisitor(Visitor visitor) async {
    if (visitor.status == VisitorStatus.checkedIn) {
      throw const AppException('Check the visitor out before cancelling.');
    }
    return _apply(visitor, VisitorStatus.cancelled, null);
  }

  VisitorModel _apply(
    Visitor visitor,
    VisitorStatus status,
    String? timestamp,
  ) {
    final index = _visitors.indexWhere((item) => item.id == visitor.id);
    if (index == -1) {
      throw const AppException('Visitor could not be found.');
    }
    final current = _visitors[index];
    final updated = VisitorModel(
      id: current.id,
      name: current.name,
      phone: current.phone,
      relation: current.relation,
      purpose: current.purpose,
      date: current.date,
      arrivalWindow: current.arrivalWindow,
      status: status,
      accessCode: current.accessCode,
      registeredBy: current.registeredBy,
      registeredOn: current.registeredOn,
      vehiclePlate: current.vehiclePlate,
      notes: current.notes,
      checkedInAt: status == VisitorStatus.checkedIn
          ? timestamp
          : current.checkedInAt,
      checkedOutAt: status == VisitorStatus.checkedOut
          ? timestamp
          : current.checkedOutAt,
    );
    _visitors[index] = updated;
    return updated;
  }

  Future<String> _uniqueCode() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      final code = VisitorCodeGenerator.generate();
      if (await findByAccessCode(code) == null) {
        return code;
      }
    }
    throw const AppException('Could not generate an access code, try again.');
  }
}
