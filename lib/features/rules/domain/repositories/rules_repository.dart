import '../entities/rules.dart';

abstract interface class RulesRepository {
  Future<List<CommunityRule>> getRules();

  Future<List<Violation>> getViolations();

  Future<List<ViolationAppeal>> getAppeals();

  Future<ViolationAppeal> submitAppeal(ViolationAppeal appeal);

  Future<ViolationAppeal> withdrawAppeal(ViolationAppeal appeal);
}
