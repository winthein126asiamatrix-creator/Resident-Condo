import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/lease.dart';

class LeaseModel extends Lease {
  const LeaseModel({
    required super.id,
    required super.reference,
    super.unitId,
    required super.unitLabel,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.currency,
    required super.monthlyRent,
    required super.securityDeposit,
    required super.rentDueDay,
    required super.owner,
    required super.tenant,
    required super.lastRentPaymentDate,
    required super.documentNames,
    required super.terms,
  });

  factory LeaseModel.fromEntity(Lease lease) {
    return LeaseModel(
      id: lease.id,
      reference: lease.reference,
      unitId: lease.unitId,
      unitLabel: lease.unitLabel,
      status: lease.status,
      startDate: lease.startDate,
      endDate: lease.endDate,
      currency: lease.currency,
      monthlyRent: lease.monthlyRent,
      securityDeposit: lease.securityDeposit,
      rentDueDay: lease.rentDueDay,
      owner: lease.owner,
      tenant: lease.tenant,
      lastRentPaymentDate: lease.lastRentPaymentDate,
      documentNames: lease.documentNames,
      terms: lease.terms,
    );
  }

  factory LeaseModel.fromJson(Map<String, dynamic> json) {
    final unit = _map(json['unit']);
    final unitLabel = _text(unit?['label']) ?? _text(json['unit_label']);
    if (unitLabel == null || unitLabel.isEmpty) {
      throw const FormatException('Lease response is missing unit.label.');
    }

    final owner = _map(json['owner']);
    final tenant = _map(json['tenant']);
    if (owner == null) {
      throw const FormatException('Lease response is missing owner.');
    }

    return LeaseModel(
      id: _requiredId(json['id'], 'id'),
      reference:
          _text(json['reference']) ??
          _text(json['name']) ??
          _text(json['code']) ??
          (throw const FormatException('Lease response is missing reference.')),
      unitId: _id(unit?['id']) ?? _id(json['unit_id']),
      unitLabel: unitLabel,
      status: _leaseStatus(
        json['status'] ?? json['state'] ?? json['lease_status'],
      ),
      startDate: _requiredDate(
        json['start_date'] ?? json['startDate'] ?? json['start'],
        'start_date',
      ),
      endDate: _requiredDate(
        json['end_date'] ?? json['endDate'] ?? json['end'],
        'end_date',
      ),
      currency: _text(json['currency'] ?? json['currency_code']) ?? '',
      monthlyRent: _requiredNumber(
        json['monthly_rent'] ?? json['monthlyRent'] ?? json['rent'],
        'monthly_rent',
      ),
      securityDeposit: _requiredNumber(
        json['security_deposit'] ?? json['securityDeposit'] ?? json['deposit'],
        'security_deposit',
      ),
      rentDueDay: _requiredInt(
        json['rent_due_day'] ?? json['rentDueDay'],
        'rent_due_day',
      ),
      owner: _party(owner, LeasePartyRole.owner),
      tenant: tenant == null ? null : _party(tenant, LeasePartyRole.tenant),
      lastRentPaymentDate: _displayDateOrRaw(
        json['last_rent_payment_date'] ?? json['lastRentPaymentDate'],
      ),
      documentNames: _documentNames(
        json['document_names'] ?? json['documents'],
      ),
      terms: _terms(json['terms']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'reference': reference,
      'unit': <String, Object?>{
        if (unitId != null) 'id': unitId,
        'label': unitLabel,
      },
      'status': _leaseStatusWire(status),
      'start_date': _isoDate(startDate),
      'end_date': _isoDate(endDate),
      'currency': currency,
      'monthly_rent': monthlyRent,
      'security_deposit': securityDeposit,
      'rent_due_day': rentDueDay,
      'owner': _partyJson(owner),
      if (tenant != null) 'tenant': _partyJson(tenant!),
      'last_rent_payment_date': lastRentPaymentDate,
      'document_names': documentNames,
      'terms': terms,
    };
  }
}

class LeaseRenewalModel extends LeaseRenewal {
  const LeaseRenewalModel({
    required super.id,
    required super.leaseId,
    required super.requestedOn,
    required super.proposedStart,
    required super.proposedEnd,
    required super.proposedRent,
    required super.status,
    required super.requestedBy,
    super.note,
    super.decidedOn,
    super.decideOn,
  });

  factory LeaseRenewalModel.fromEntity(LeaseRenewal renewal) {
    return LeaseRenewalModel(
      id: renewal.id,
      leaseId: renewal.leaseId,
      requestedOn: renewal.requestedOn,
      proposedStart: renewal.proposedStart,
      proposedEnd: renewal.proposedEnd,
      proposedRent: renewal.proposedRent,
      status: renewal.status,
      requestedBy: renewal.requestedBy,
      note: renewal.note,
      decidedOn: renewal.decidedOn,
      decideOn: renewal.decideOn,
    );
  }

  factory LeaseRenewalModel.fromJson(Map<String, dynamic> json) {
    final decideOnValue = json['decide_on'] ?? json['decideOn'];
    final decidedOnValue = json['decided_on'] ?? json['decidedOn'];
    final decidedOn = _optionalDisplayDate(
      decidedOnValue ?? json['updated_on'],
    );
    final decideOn = _optionalBool(decideOnValue) ?? false;
    return LeaseRenewalModel(
      id: _requiredId(json['id'], 'id'),
      leaseId: _requiredId(
        json['lease_id'] ?? json['leaseId'] ?? json['lease'],
        'lease_id',
      ),
      requestedOn: _displayDateOrRaw(
        json['requested_on'] ?? json['requestedOn'] ?? json['created_on'],
      ),
      proposedStart: _displayDate(
        json['proposed_start'] ?? json['proposedStart'] ?? json['start_date'],
        'proposed_start',
      ),
      proposedEnd: _displayDate(
        json['proposed_end'] ?? json['proposedEnd'] ?? json['end_date'],
        'proposed_end',
      ),
      proposedRent: _requiredNumber(
        json['proposed_rent'] ?? json['proposedRent'] ?? json['rent'],
        'proposed_rent',
      ),
      status: _renewalStatus(json['status'] ?? json['state']),
      requestedBy:
          _requestedBy(json['requested_by'] ?? json['requestedBy']) ?? '',
      note: _text(json['note']) ?? '',
      decidedOn: decidedOn,
      decideOn: decideOn,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'lease_id': leaseId,
      'requested_on': requestedOn,
      'proposed_start': proposedStart,
      'proposed_end': proposedEnd,
      'proposed_rent': proposedRent,
      'status': _renewalStatusWire(status),
      'requested_by': requestedBy,
      'note': note,
      'decided_on': decidedOn,
      'decide_on': decideOn,
    };
  }
}

LeaseParty _party(Map<String, dynamic> json, LeasePartyRole role) {
  final name = _text(json['name']);
  if (name == null || name.isEmpty) {
    throw FormatException('Lease ${role.name} is missing name.');
  }
  return LeaseParty(
    id: _id(json['id'] ?? json['partner_id']),
    name: name,
    role: role,
    phone: _text(json['phone']) ?? '',
    email: _text(json['email']) ?? '',
    idNumber: _text(json['id_number'] ?? json['idNumber']) ?? '',
  );
}

Map<String, Object?> _partyJson(LeaseParty party) {
  return <String, Object?>{
    if (party.id != null) 'id': party.id,
    'name': party.name,
    'role': party.role.name,
    'phone': party.phone,
    'email': party.email,
    'id_number': party.idNumber,
  };
}

LeaseStatus _leaseStatus(Object? value) {
  final key = _statusKey(value);
  return switch (key) {
    'active' => LeaseStatus.active,
    'expiring_soon' || 'expiringsoon' || 'expiring' => LeaseStatus.expiringSoon,
    'expired' => LeaseStatus.expired,
    'renewed' => LeaseStatus.renewed,
    'terminated' || 'terminate' || 'termination' => LeaseStatus.terminated,
    // A status this build does not know must not fail the whole lease list.
    // [LeaseStatus.active] is the compatibility fallback only; it is not proof
    // that the backend lease is active, so no permission is derived from it.
    _ => _unknownLeaseStatus(key),
  };
}

RenewalStatus _renewalStatus(Object? value) {
  final key = _statusKey(value);
  return switch (key) {
    'pending' => RenewalStatus.pending,
    'approved' => RenewalStatus.approved,
    'declined' => RenewalStatus.declined,
    'withdrawn' => RenewalStatus.withdrawn,
    'rejected' => RenewalStatus.rejected,
    'cancelled' || 'canceled' => RenewalStatus.cancelled,
    // A renewal this build does not recognise falls back to the terminal,
    // non-blocking [RenewalStatus.cancelled] state. It is not treated as
    // pending or approved, so it never blocks a new request or changes the
    // displayed term.
    _ => _unknownRenewalStatus(key),
  };
}

LeaseStatus _unknownLeaseStatus(String key) {
  superPrint(
    'Unknown lease status "${key.isEmpty ? '<empty>' : key}"; '
    'falling back to active.',
    title: 'LeaseStatus.fromApi',
  );
  return LeaseStatus.active;
}

RenewalStatus _unknownRenewalStatus(String key) {
  superPrint(
    'Unknown renewal status "${key.isEmpty ? '<empty>' : key}"; '
    'falling back to cancelled.',
    title: 'RenewalStatus.fromApi',
  );
  return RenewalStatus.cancelled;
}

String _statusKey(Object? value) {
  final raw = switch (value) {
    Map() => _text(value['value'] ?? value['code'] ?? value['name']) ?? '',
    _ => _text(value) ?? '',
  };
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
}

String _leaseStatusWire(LeaseStatus status) {
  return switch (status) {
    LeaseStatus.active => 'active',
    LeaseStatus.expiringSoon => 'expiring_soon',
    LeaseStatus.expired => 'expired',
    LeaseStatus.renewed => 'renewed',
    LeaseStatus.terminated => 'terminated',
  };
}

String _renewalStatusWire(RenewalStatus status) {
  return switch (status) {
    RenewalStatus.pending => 'pending',
    RenewalStatus.approved => 'approved',
    RenewalStatus.declined => 'declined',
    RenewalStatus.withdrawn => 'withdrawn',
    RenewalStatus.rejected => 'rejected',
    RenewalStatus.cancelled => 'cancelled',
  };
}

String? _requestedBy(Object? value) {
  return switch (value) {
    Map() => _text(value['name'] ?? value['label']),
    _ => _text(value),
  };
}

String? _id(Object? value) {
  final unwrapped = value is Map ? value['id'] : value;
  final text = _text(unwrapped);
  return text == null || text.isEmpty ? null : text;
}

String _requiredId(Object? value, String field) {
  final id = _id(value);
  if (id == null) {
    throw FormatException('Lease response is missing $field.');
  }
  return id;
}

String? _text(Object? value) {
  if (value == null || value is bool) return null;
  if (value is String) return value.trim();
  if (value is num) return value.toString();
  return value.toString();
}

Map<String, dynamic>? _map(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

double _requiredNumber(Object? value, String field) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(_text(value) ?? '');
  if (number == null) {
    throw FormatException('Lease response has an invalid $field.');
  }
  return number;
}

int _requiredInt(Object? value, String field) {
  final number = value is num
      ? value.toInt()
      : int.tryParse(_text(value) ?? '');
  if (number == null) {
    throw FormatException('Lease response has an invalid $field.');
  }
  return number;
}

DateTime _requiredDate(Object? value, String field) {
  final date = _tryDate(value);
  if (date == null) {
    throw FormatException('Lease response has an invalid $field.');
  }
  return date;
}

String _displayDate(Object? value, String field) {
  return AppDates.format(_requiredDate(value, field));
}

String _displayDateOrRaw(Object? value) {
  final text = _text(value);
  if (text == null || text.isEmpty || text.toLowerCase() == 'false') return '';
  final date = _tryDate(text);
  return date == null ? text : AppDates.format(date);
}

String? _optionalDisplayDate(Object? value) {
  final text = _text(value);
  if (text == null || text.isEmpty) return null;
  final date = _tryDate(text);
  return date == null ? text : AppDates.format(date);
}

bool? _optionalBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
  }
  return null;
}

DateTime? _tryDate(Object? value) {
  if (value is DateTime) return AppDates.dateOnly(value);
  final text = _text(value);
  if (text == null || text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) return AppDates.dateOnly(iso);

  final display = AppDates.parse(text);
  if (AppDates.format(display).toLowerCase() == text.toLowerCase()) {
    return display;
  }
  return null;
}

String _isoDate(DateTime value) {
  final date = AppDates.dateOnly(value);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

List<String> _documentNames(Object? value) {
  if (value is! List) return const <String>[];
  return <String>[
    for (final item in value)
      if (item is Map)
        ...?_optionalList(_text(item['name'] ?? item['file_name']))
      else
        ...?_optionalList(_text(item)),
  ];
}

List<String> _terms(Object? value) {
  if (value is! List) return const <String>[];
  return <String>[
    for (final item in value)
      if (item is Map)
        ...?_optionalList(_text(item['text'] ?? item['label']))
      else
        ...?_optionalList(_text(item)),
  ];
}

Iterable<String>? _optionalList(String? value) {
  if (value == null || value.isEmpty) return null;
  return <String>[value];
}
