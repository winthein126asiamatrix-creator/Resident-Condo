import '../entities/lease.dart';
import '../repositories/lease_repository.dart';

class LeaseUseCases {
  const LeaseUseCases(this.repository);

  final LeaseRepository repository;

  Future<List<Lease>> getLeases() => repository.getLeases();

  Future<Lease?> getLease(String id) => repository.getLease(id);

  Future<List<LeaseRenewal>> getRenewals() => repository.getRenewals();

  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) =>
      repository.createRenewal(renewal);

  Future<LeaseRenewal> withdrawRenewal(String id) =>
      repository.withdrawRenewal(id);
}
