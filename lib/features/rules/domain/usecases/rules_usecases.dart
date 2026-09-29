import '../entities/rules.dart';
import '../repositories/rules_repository.dart';

class RulesUseCases {
  const RulesUseCases(this.repository);

  final RulesRepository repository;

  Future<List<CommunityRule>> getRules() => repository.getRules();

  Future<List<Violation>> getViolations() => repository.getViolations();

  Future<List<ViolationAppeal>> getAppeals() => repository.getAppeals();

  Future<ViolationAppeal> submitAppeal(ViolationAppeal appeal) =>
      repository.submitAppeal(appeal);

  Future<ViolationAppeal> withdrawAppeal(ViolationAppeal appeal) =>
      repository.withdrawAppeal(appeal);
}
