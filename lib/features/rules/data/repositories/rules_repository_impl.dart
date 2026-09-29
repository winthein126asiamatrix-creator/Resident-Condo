import '../../domain/entities/rules.dart';
import '../../domain/repositories/rules_repository.dart';
import '../datasources/rules_local_data_source.dart';

class RulesRepositoryImpl implements RulesRepository {
  const RulesRepositoryImpl(this.localDataSource);

  final RulesLocalDataSource localDataSource;

  @override
  Future<List<CommunityRule>> getRules() => localDataSource.getRules();

  @override
  Future<List<Violation>> getViolations() => localDataSource.getViolations();

  @override
  Future<List<ViolationAppeal>> getAppeals() => localDataSource.getAppeals();

  @override
  Future<ViolationAppeal> submitAppeal(ViolationAppeal appeal) =>
      localDataSource.submitAppeal(appeal);

  @override
  Future<ViolationAppeal> withdrawAppeal(ViolationAppeal appeal) =>
      localDataSource.withdrawAppeal(appeal);
}
