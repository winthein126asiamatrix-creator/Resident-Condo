import '../entities/lease.dart';

abstract interface class LeaseRepository {
  Future<List<Lease>> getLeases();

  Future<Lease?> getLease(String id);

  Future<List<LeaseRenewal>> getRenewals();

  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal);

  Future<LeaseRenewal> withdrawRenewal(String id);
}
