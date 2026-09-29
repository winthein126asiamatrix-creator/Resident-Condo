import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/rules.dart';

class RulesLocalDataSource {
  RulesLocalDataSource()
    : _rules = List.of(_initialRules),
      _violations = List.of(_initialViolations),
      _appeals = List.of(_initialAppeals);

  final List<CommunityRule> _rules;
  final List<Violation> _violations;
  final List<ViolationAppeal> _appeals;

  static const List<CommunityRule> _initialRules = [
    CommunityRule(
      id: 'rule-noise-01',
      code: 'CR-01',
      title: 'Quiet hours',
      category: RuleCategory.noise,
      summary:
          'No noise above conversation level between 10 PM and 7 AM on weekdays '
          'and until 9 AM on weekends.',
      details:
          'Residents are asked to keep music, parties and drilling inside the '
          'unit during quiet hours. Repeated breaches may lead to a fine and, in '
          'serious cases, a lease warning.',
      fineAmount: 80,
      updatedOn: 'Jan 10, 2026',
    ),
    CommunityRule(
      id: 'rule-parking-02',
      code: 'CR-02',
      title: 'Parking allocation',
      category: RuleCategory.parking,
      summary:
          'Vehicles must be parked inside the allocated bay. Guest bays are for '
          'a maximum of 24 hours.',
      details:
          'Obstruction of driveways, visitor bays or fire lanes is not permitted '
          'at any time. Repeat offences can lead to clamping and a recovery fee.',
      fineAmount: 120,
      updatedOn: 'Feb 02, 2026',
    ),
    CommunityRule(
      id: 'rule-pets-03',
      code: 'CR-03',
      title: 'Pets',
      category: RuleCategory.pets,
      summary:
          'Only approved pets are allowed, and owners must keep them on a leash '
          'in common areas.',
      details:
          'Pet registration must be renewed annually. Damage to common areas '
          'caused by pets is chargeable to the unit owner.',
      fineAmount: 60,
      updatedOn: 'Mar 15, 2026',
    ),
    CommunityRule(
      id: 'rule-appearance-04',
      code: 'CR-04',
      title: 'Balcony and facade appearance',
      category: RuleCategory.appearance,
      summary:
          'Balconies must be kept free of laundry, storage and unsightly items '
          'visible from the street.',
      details:
          'Plants must be contained within balcony planters. Drying laundry may '
          'only be hung between 7 AM and 9 PM.',
      fineAmount: 50,
      updatedOn: 'Apr 02, 2026',
    ),
    CommunityRule(
      id: 'rule-waste-05',
      code: 'CR-05',
      title: 'Waste disposal',
      category: RuleCategory.waste,
      summary:
          'Rubbish must be bagged, labelled with the unit number and placed in '
          'the bin store at the scheduled times.',
      details:
          'Bulky items require a booked disposal service. Leaving items in '
          'corridors or lifts is prohibited.',
      fineAmount: 40,
      updatedOn: 'May 20, 2026',
    ),
    CommunityRule(
      id: 'rule-safety-06',
      code: 'CR-06',
      title: 'Fire and building safety',
      category: RuleCategory.safety,
      summary:
          'Fire doors must stay closed and corridors must remain clear at all '
          'times.',
      details:
          'Storing combustible items in corridors is a serious breach. Cooking '
          'with portable gas appliances is not permitted.',
      fineAmount: 200,
      updatedOn: 'Jun 11, 2026',
    ),
  ];

  static const List<Violation> _initialViolations = [
    Violation(
      id: 'violation-003',
      reference: 'VIO-2026-009',
      ruleId: 'rule-noise-01',
      ruleTitle: 'Quiet hours',
      category: RuleCategory.noise,
      issuedOn: 'Sep 12, 2026',
      description:
          'Noise complaint confirmed by two neighbours at 11:40 PM on Sep 11. '
          'A reminder notice was issued on Sep 13.',
      location: 'Tower A · Level 12',
      amount: 80,
      status: ViolationStatus.open,
      dueDate: 'Oct 12, 2026',
      evidenceNote: 'Two written statements on file.',
    ),
    Violation(
      id: 'violation-002',
      reference: 'VIO-2026-006',
      ruleId: 'rule-waste-05',
      ruleTitle: 'Waste disposal',
      category: RuleCategory.waste,
      issuedOn: 'Aug 28, 2026',
      description:
          'Unlabelled refuse bags were found in the level 12 corridor twice in '
          'one week.',
      location: 'Tower A · Level 12',
      amount: 40,
      status: ViolationStatus.appealed,
      dueDate: 'Sep 28, 2026',
      evidenceNote: 'Corridor camera still captured.',
    ),
    Violation(
      id: 'violation-001',
      reference: 'VIO-2026-002',
      ruleId: 'rule-parking-02',
      ruleTitle: 'Parking allocation',
      category: RuleCategory.parking,
      issuedOn: 'Jun 15, 2026',
      description: 'Vehicle parked across two bays on Jun 14.',
      location: 'Basement 2',
      amount: 120,
      status: ViolationStatus.paid,
      dueDate: 'Jul 15, 2026',
    ),
  ];

  static const List<ViolationAppeal> _initialAppeals = [
    ViolationAppeal(
      id: 'appeal-001',
      violationId: 'violation-002',
      submittedOn: 'Sep 01, 2026',
      reason:
          'The bags belonged to the neighbouring unit and were left by their '
          'cleaning contractor. Cleaning is arranged on Mondays.',
      requestedOutcome: 'Waive the fine',
      status: AppealStatus.underReview,
    ),
  ];

  Future<List<CommunityRule>> getRules() async => List.unmodifiable(_rules);

  Future<List<Violation>> getViolations() async => List.unmodifiable(_violations);

  Future<List<ViolationAppeal>> getAppeals() async => List.unmodifiable(_appeals);

  Future<ViolationAppeal> submitAppeal(ViolationAppeal appeal) async {
    final violation = _findViolation(appeal.violationId);
    if (violation == null) {
      throw const AppException('Violation could not be found.');
    }
    if (!violation.canAppeal) {
      throw const AppException('This violation can no longer be appealed.');
    }
    if (appeal.reason.trim().length < 20) {
      throw const AppException(
        'Please explain your appeal in at least 20 characters.',
      );
    }
    for (final existing in _appeals) {
      if (existing.violationId == appeal.violationId && existing.isOpen) {
        throw const AppException('An appeal is already under review.');
      }
    }

    final created = ViolationAppeal(
      id: 'appeal-${DateTime.now().microsecondsSinceEpoch}',
      violationId: appeal.violationId,
      submittedOn: appeal.submittedOn,
      reason: appeal.reason.trim(),
      requestedOutcome: appeal.requestedOutcome,
      status: AppealStatus.pending,
    );
    _appeals.insert(0, created);
    _updateViolationStatus(appeal.violationId, ViolationStatus.appealed);
    return created;
  }

  Future<ViolationAppeal> withdrawAppeal(ViolationAppeal appeal) async {
    final index = _appeals.indexWhere((item) => item.id == appeal.id);
    if (index == -1) {
      throw const AppException('Appeal could not be found.');
    }
    if (!_appeals[index].isOpen) {
      throw const AppException('Only an open appeal can be withdrawn.');
    }
    final updated = _appeals[index].copyWith(
      status: AppealStatus.withdrawn,
      decidedOn: 'Sep 25, 2026',
      decisionNote: 'Withdrawn by the resident.',
    );
    _appeals[index] = updated;
    _updateViolationStatus(appeal.violationId, ViolationStatus.open);
    return updated;
  }

  Violation? _findViolation(String id) {
    for (final violation in _violations) {
      if (violation.id == id) {
        return violation;
      }
    }
    return null;
  }

  void _updateViolationStatus(String id, ViolationStatus status) {
    final index = _violations.indexWhere((violation) => violation.id == id);
    if (index != -1) {
      _violations[index] = _violations[index].copyWith(status: status);
    }
  }
}
