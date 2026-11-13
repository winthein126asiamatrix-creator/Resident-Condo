import '../entities/lease.dart';

abstract interface class LeaseRepository {
  Future<List<Lease>> getLeases();

  Future<List<Lease>?> getCachedLeases();

  Future<Lease?> getLease(String id);

  Future<List<LeaseRenewal>> getRenewals();

  Future<List<LeaseRenewal>?> getCachedRenewals();

  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal);

  Future<LeaseRenewal> withdrawRenewal(LeaseRenewal renewal);
}
