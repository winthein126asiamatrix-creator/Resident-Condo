import '../../domain/entities/lease.dart';
import '../../domain/repositories/lease_repository.dart';
import '../datasources/lease_local_data_source.dart';
import '../datasources/lease_remote_data_source.dart';

class LeaseRepositoryImpl implements LeaseRepository {
  const LeaseRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final LeaseRemoteDataSource remoteDataSource;
  final LeaseLocalDataSource localDataSource;

  @override
  Future<List<Lease>> getLeases() async {
    final leases = await remoteDataSource.getLeases();
    await localDataSource.saveLeases(leases);
    return leases;
  }

  @override
  Future<List<Lease>?> getCachedLeases() => localDataSource.readLeases();

  @override
  Future<Lease?> getLease(String id) async {
    final cached = await localDataSource.readLeases();
    if (cached == null) return null;
    for (final lease in cached) {
      if (lease.id == id) return lease;
    }
    return null;
  }

  @override
  Future<List<LeaseRenewal>> getRenewals() async {
    final renewals = await remoteDataSource.getRenewals();
    await localDataSource.saveRenewals(renewals);
    return renewals;
  }

  @override
  Future<List<LeaseRenewal>?> getCachedRenewals() =>
      localDataSource.readRenewals();

  @override
  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) =>
      remoteDataSource.createRenewal(renewal);

  @override
  Future<LeaseRenewal> withdrawRenewal(LeaseRenewal renewal) =>
      remoteDataSource.withdrawRenewal(renewal);
}
