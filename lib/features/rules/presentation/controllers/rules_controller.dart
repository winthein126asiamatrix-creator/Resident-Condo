import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/rules.dart';
import '../../domain/usecases/rules_usecases.dart';

enum RulesTab { rules, violations }

extension RulesTabIndex on RulesTab {
  /// Position in the tab strip, used to drive the highlighted segment.
  int get index => RulesTab.values.indexOf(this);
}

class RulesController extends GetxController {
  RulesController(this.useCases);

  final RulesUseCases useCases;
  final rules = <CommunityRule>[].obs;
  final violations = <Violation>[].obs;
  final appeals = <ViolationAppeal>[].obs;
  final selectedRule = Rxn<CommunityRule>();
  final selectedViolation = Rxn<Violation>();
  final tab = RulesTab.violations.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  int get openViolationCount =>
      violations.where((violation) => violation.isOverdue).length;

  double get outstandingFines => violations
      .where(
        (violation) =>
            violation.status == ViolationStatus.open ||
            violation.status == ViolationStatus.appealed,
      )
      .fold(0, (total, violation) => total + violation.amount);

  List<ViolationAppeal> appealsFor(Violation violation) =>
      appeals.where((appeal) => appeal.violationId == violation.id).toList();

  ViolationAppeal? appealFor(Violation violation) {
    for (final appeal in appeals) {
      if (appeal.violationId == violation.id && appeal.isOpen) {
        return appeal;
      }
    }
    return null;
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      rules.assignAll(await useCases.getRules());
      violations.assignAll(await useCases.getViolations());
      appeals.assignAll(await useCases.getAppeals());
      final rule = selectedRule.value;
      if (rule != null) {
        selectedRule.value = _findRule(rule.id) ?? rule;
      }
      final violation = selectedViolation.value;
      if (violation != null) {
        selectedViolation.value = _findViolation(violation.id) ?? violation;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load rules and violations.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectTab(RulesTab value) {
    tab.value = value;
  }

  void selectRule(CommunityRule rule) {
    selectedRule.value = rule;
  }

  void selectViolation(Violation violation) {
    selectedViolation.value = violation;
  }

  Future<ViolationAppeal?> submitAppeal({
    required Violation violation,
    required String reason,
    required String requestedOutcome,
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final appeal = await useCases.submitAppeal(
        ViolationAppeal(
          id: 'local-appeal',
          violationId: violation.id,
          submittedOn: 'Sep 25, 2026',
          reason: reason,
          requestedOutcome: requestedOutcome,
          status: AppealStatus.pending,
        ),
      );
      appeals.insert(0, appeal);
      final index = violations.indexWhere((item) => item.id == violation.id);
      if (index != -1) {
        violations[index] = violations[index].copyWith(
          status: ViolationStatus.appealed,
        );
      }
      selectedViolation.value = violations.firstWhere(
        (item) => item.id == violation.id,
        orElse: () => violation,
      );
      return appeal;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to submit the appeal.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<ViolationAppeal?> withdrawAppeal(ViolationAppeal appeal) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.withdrawAppeal(appeal);
      final index = appeals.indexWhere((item) => item.id == appeal.id);
      if (index != -1) {
        appeals[index] = updated;
      }
      await loadAll();
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to withdraw the appeal.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  CommunityRule? _findRule(String id) {
    for (final rule in rules) {
      if (rule.id == id) {
        return rule;
      }
    }
    return null;
  }

  Violation? _findViolation(String id) {
    for (final violation in violations) {
      if (violation.id == id) {
        return violation;
      }
    }
    return null;
  }
}
