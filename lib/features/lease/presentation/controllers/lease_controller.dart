import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/resident_role.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/lease.dart';
import '../../domain/usecases/lease_usecases.dart';

class LeaseController extends GetxController {
  LeaseController(this.useCases);

  final LeaseUseCases useCases;
  final leases = <Lease>[].obs;
  final renewals = <LeaseRenewal>[].obs;
  final selectedLease = Rxn<Lease>();
  final role = ResidentRole.owner.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadLeases();
  }

  Lease? get activeLease {
    for (final lease in leases) {
      if (!lease.hasExpired) {
        return lease;
      }
    }
    return leases.isEmpty ? null : leases.first;
  }

  LeaseRenewal? get pendingRenewal {
    for (final renewal in renewals) {
      if (renewal.status == RenewalStatus.pending) {
        return renewal;
      }
    }
    return null;
  }

  List<LeaseRenewal> renewalsFor(Lease lease) =>
      renewals.where((renewal) => renewal.leaseId == lease.id).toList();

  /// Tenants see the rent they owe, owners see the rent they collect.
  String get rentPerspectiveLabel =>
      role.value.paysRent ? 'Rent you pay' : 'Rent you collect';

  Future<void> loadLeases() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loadedLeases = await useCases.getLeases();
      final loadedRenewals = await useCases.getRenewals();
      leases.assignAll(loadedLeases);
      renewals.assignAll(loadedRenewals);
      final selected = selectedLease.value;
      if (selected != null) {
        selectedLease.value = _findLease(selected.id) ?? selected;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load lease information.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectLease(Lease lease) {
    selectedLease.value = lease;
    errorMessage.value = null;
  }

  void applyRole(ResidentRole next) {
    role.value = next;
  }

  Future<LeaseRenewal?> requestRenewal({
    required Lease lease,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required double proposedRent,
    String note = '',
  }) async {
    if (proposedRent <= 0) {
      errorMessage.value = 'Enter the proposed monthly rent.';
      return null;
    }
    if (!proposedEnd.isAfter(proposedStart)) {
      errorMessage.value = 'The end date must be after the start date.';
      return null;
    }

    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final renewal = await useCases.createRenewal(
        LeaseRenewal(
          id: 'local-renewal',
          leaseId: lease.id,
          requestedOn: AppDates.format(DateTime(2026, 9, 25)),
          proposedStart: AppDates.format(proposedStart),
          proposedEnd: AppDates.format(proposedEnd),
          proposedRent: proposedRent,
          status: RenewalStatus.pending,
          requestedBy: role.value.label,
          note: note,
        ),
      );
      renewals.removeWhere(
        (item) => item.leaseId == lease.id && item.status == RenewalStatus.pending,
      );
      renewals.insert(0, renewal);
      return renewal;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to send the renewal request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<LeaseRenewal?> withdrawRenewal(LeaseRenewal renewal) async {
    errorMessage.value = null;
    try {
      final updated = await useCases.withdrawRenewal(renewal.id);
      final index = renewals.indexWhere((item) => item.id == renewal.id);
      if (index != -1) {
        renewals[index] = updated;
      }
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to withdraw the renewal request.';
      return null;
    }
  }

  Lease? _findLease(String id) {
    for (final lease in leases) {
      if (lease.id == id) {
        return lease;
      }
    }
    return null;
  }
}
