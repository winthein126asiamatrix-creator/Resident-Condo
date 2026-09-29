import '../../../../core/utils/app_dates.dart';

enum LeaseStatus { active, expiringSoon, expired, renewed }

extension LeaseStatusLabel on LeaseStatus {
  String get label {
    switch (this) {
      case LeaseStatus.active:
        return 'Active';
      case LeaseStatus.expiringSoon:
        return 'Expiring soon';
      case LeaseStatus.expired:
        return 'Expired';
      case LeaseStatus.renewed:
        return 'Renewed';
    }
  }
}

enum LeasePartyRole { owner, tenant, agent }

extension LeasePartyRoleLabel on LeasePartyRole {
  String get label {
    switch (this) {
      case LeasePartyRole.owner:
        return 'Owner / Landlord';
      case LeasePartyRole.tenant:
        return 'Tenant';
      case LeasePartyRole.agent:
        return 'Leasing agent';
    }
  }
}

class LeaseParty {
  const LeaseParty({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.idNumber,
  });

  final String name;
  final LeasePartyRole role;
  final String phone;
  final String email;
  final String idNumber;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

enum RenewalStatus { pending, approved, declined, withdrawn }

extension RenewalStatusLabel on RenewalStatus {
  String get label {
    switch (this) {
      case RenewalStatus.pending:
        return 'Pending review';
      case RenewalStatus.approved:
        return 'Approved';
      case RenewalStatus.declined:
        return 'Declined';
      case RenewalStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}

class LeaseRenewal {
  const LeaseRenewal({
    required this.id,
    required this.leaseId,
    required this.requestedOn,
    required this.proposedStart,
    required this.proposedEnd,
    required this.proposedRent,
    required this.status,
    required this.requestedBy,
    this.note = '',
    this.decidedOn,
  });

  final String id;
  final String leaseId;
  final String requestedOn;
  final String proposedStart;
  final String proposedEnd;
  final double proposedRent;
  final RenewalStatus status;
  final String requestedBy;
  final String note;
  final String? decidedOn;

  LeaseRenewal copyWith({RenewalStatus? status, String? decidedOn}) {
    return LeaseRenewal(
      id: id,
      leaseId: leaseId,
      requestedOn: requestedOn,
      proposedStart: proposedStart,
      proposedEnd: proposedEnd,
      proposedRent: proposedRent,
      status: status ?? this.status,
      requestedBy: requestedBy,
      note: note,
      decidedOn: decidedOn ?? this.decidedOn,
    );
  }
}

class Lease {
  const Lease({
    required this.id,
    required this.reference,
    required this.unitLabel,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.rentDueDay,
    required this.owner,
    required this.tenant,
    required this.lastRentPaymentDate,
    required this.documentNames,
    required this.terms,
  });

  final String id;
  final String reference;
  final String unitLabel;
  final LeaseStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double securityDeposit;
  final int rentDueDay;
  final LeaseParty owner;
  final LeaseParty tenant;
  final String lastRentPaymentDate;
  final List<String> documentNames;
  final List<String> terms;

  int get totalDays {
    final days = AppDates.daysBetween(startDate, endDate);
    return days <= 0 ? 1 : days;
  }

  int get elapsedDays {
    final days = AppDates.daysBetween(startDate, DateTime(2026, 9, 25));
    return days.clamp(0, totalDays);
  }

  /// 0..1 progress through the current term.
  double get progress => elapsedDays / totalDays;

  int get daysRemaining {
    final days = AppDates.daysBetween(DateTime(2026, 9, 25), endDate);
    return days < 0 ? 0 : days;
  }

  bool get isExpiringSoon => daysRemaining <= 60 && daysRemaining > 0;

  bool get hasExpired => daysRemaining == 0;

  /// Rent already billed for the term at the current monthly rate.
  double get contractedValue => monthlyRent * (totalDays / 30.44).round();

  Lease copyWith({LeaseStatus? status}) {
    return Lease(
      id: id,
      reference: reference,
      unitLabel: unitLabel,
      status: status ?? this.status,
      startDate: startDate,
      endDate: endDate,
      monthlyRent: monthlyRent,
      securityDeposit: securityDeposit,
      rentDueDay: rentDueDay,
      owner: owner,
      tenant: tenant,
      lastRentPaymentDate: lastRentPaymentDate,
      documentNames: documentNames,
      terms: terms,
    );
  }
}
