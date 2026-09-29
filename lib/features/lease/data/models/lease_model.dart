import '../../domain/entities/lease.dart';

class LeaseModel extends Lease {
  const LeaseModel({
    required super.id,
    required super.reference,
    required super.unitLabel,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.monthlyRent,
    required super.securityDeposit,
    required super.rentDueDay,
    required super.owner,
    required super.tenant,
    required super.lastRentPaymentDate,
    required super.documentNames,
    required super.terms,
  });
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
  });
}
