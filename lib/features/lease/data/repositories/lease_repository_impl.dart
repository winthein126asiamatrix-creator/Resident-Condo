import '../../domain/entities/lease.dart';
import '../../domain/repositories/lease_repository.dart';
import '../datasources/lease_local_data_source.dart';

class LeaseRepositoryImpl implements LeaseRepository {
  const LeaseRepositoryImpl(this.localDataSource);

  final LeaseLocalDataSource localDataSource;

  @override
  Future<List<Lease>> getLeases() async {
    final leases = await localDataSource.getLeases();
    return List<Lease>.of(leases);
  }

  @override
  Future<Lease?> getLease(String id) => localDataSource.getLease(id);

  @override
  Future<List<LeaseRenewal>> getRenewals() async {
    final renewals = await localDataSource.getRenewals();
    return List<LeaseRenewal>.of(renewals);
  }

  @override
  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) =>
      localDataSource.createRenewal(renewal);

  @override
  Future<LeaseRenewal> withdrawRenewal(String id) =>
      localDataSource.withdrawRenewal(id);
}
