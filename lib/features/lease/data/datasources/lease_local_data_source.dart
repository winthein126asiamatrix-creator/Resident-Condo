import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/lease.dart';
import '../models/lease_model.dart';

class LeaseLocalDataSource {
  LeaseLocalDataSource()
    : _leases = List<LeaseModel>.of(_initialLeases),
      _renewals = List<LeaseRenewalModel>.of(_initialRenewals);

  final List<LeaseModel> _leases;
  final List<LeaseRenewalModel> _renewals;

  static final List<LeaseModel> _initialLeases = [
    LeaseModel(
      id: 'lease-2026-1205',
      reference: 'LSE-2026-0042',
      unitLabel: 'Tower A · 1205',
      status: LeaseStatus.expiringSoon,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 10, 31),
      monthlyRent: 2400,
      securityDeposit: 2400,
      rentDueDay: 1,
      owner: const LeaseParty(
        name: 'Alex Johnson',
        role: LeasePartyRole.owner,
        phone: '+959772611100',
        email: 'alex.johnson@example.com',
        idNumber: 'ID-88214-A',
      ),
      tenant: const LeaseParty(
        name: 'Jamie Rivera',
        role: LeasePartyRole.tenant,
        phone: '+959772611100',
        email: 'jamie.rivera@example.com',
        idNumber: 'ID-40019-J',
      ),
      lastRentPaymentDate: 'Sep 01, 2026',
      documentNames: ['Signed lease agreement.pdf', 'Move-in checklist.pdf'],
      terms: const [
        'Rent is due on the 1st of each month; a 5 day grace period applies.',
        'Monthly condo fee is paid separately to the management company.',
        'One 12-month renewal option is available with 60 days notice.',
        'Pets are not permitted without written approval.',
      ],
    ),
  ];

  static final List<LeaseRenewalModel> _initialRenewals = [
    LeaseRenewalModel(
      id: 'renewal-2026-0007',
      leaseId: 'lease-2026-1205',
      requestedOn: 'Sep 05, 2026',
      proposedStart: 'Nov 01, 2026',
      proposedEnd: 'Oct 31, 2027',
      proposedRent: 2460,
      status: RenewalStatus.declined,
      requestedBy: 'Alex Johnson',
      note: 'Tenant asked to review the rent increase before agreeing.',
      decidedOn: 'Sep 10, 2026',
    ),
  ];

  Future<List<LeaseModel>> getLeases() async {
    return List<LeaseModel>.unmodifiable(_leases);
  }

  Future<LeaseModel?> getLease(String id) async {
    for (final lease in _leases) {
      if (lease.id == id) {
        return lease;
      }
    }
    return null;
  }

  Future<List<LeaseRenewalModel>> getRenewals() async {
    return List<LeaseRenewalModel>.unmodifiable(_renewals);
  }

  Future<LeaseRenewalModel> createRenewal(LeaseRenewal renewal) async {
    final lease = await getLease(renewal.leaseId);
    if (lease == null) {
      throw const AppException('Lease could not be found.');
    }
    if (renewal.proposedRent <= 0) {
      throw const AppException('Enter the proposed monthly rent.');
    }
    final start = AppDates.parse(renewal.proposedStart);
    final end = AppDates.parse(renewal.proposedEnd);
    if (!end.isAfter(start)) {
      throw const AppException('The end date must be after the start date.');
    }

    _renewals.removeWhere(
      (item) =>
          item.leaseId == renewal.leaseId &&
          item.status == RenewalStatus.pending,
    );

    final created = LeaseRenewalModel(
      id: 'renewal-${DateTime.now().microsecondsSinceEpoch}',
      leaseId: renewal.leaseId,
      requestedOn: renewal.requestedOn,
      proposedStart: renewal.proposedStart,
      proposedEnd: renewal.proposedEnd,
      proposedRent: renewal.proposedRent,
      status: RenewalStatus.pending,
      requestedBy: renewal.requestedBy,
      note: renewal.note,
    );
    _renewals.insert(0, created);
    return created;
  }

  Future<LeaseRenewalModel> withdrawRenewal(String id) async {
    final index = _renewals.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const AppException('Renewal request could not be found.');
    }
    if (_renewals[index].status != RenewalStatus.pending) {
      throw const AppException('Only a pending renewal can be withdrawn.');
    }
    final updated = LeaseRenewalModel(
      id: _renewals[index].id,
      leaseId: _renewals[index].leaseId,
      requestedOn: _renewals[index].requestedOn,
      proposedStart: _renewals[index].proposedStart,
      proposedEnd: _renewals[index].proposedEnd,
      proposedRent: _renewals[index].proposedRent,
      status: RenewalStatus.withdrawn,
      requestedBy: _renewals[index].requestedBy,
      note: _renewals[index].note,
      decidedOn: 'Sep 25, 2026',
    );
    _renewals[index] = updated;
    return updated;
  }
}
