enum RuleCategory { noise, parking, pets, appearance, waste, safety, commonAreas }

extension RuleCategoryLabel on RuleCategory {
  String get label {
    switch (this) {
      case RuleCategory.noise:
        return 'Noise';
      case RuleCategory.parking:
        return 'Parking';
      case RuleCategory.pets:
        return 'Pets';
      case RuleCategory.appearance:
        return 'Appearance';
      case RuleCategory.waste:
        return 'Waste';
      case RuleCategory.safety:
        return 'Safety';
      case RuleCategory.commonAreas:
        return 'Common areas';
    }
  }
}

class CommunityRule {
  const CommunityRule({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.summary,
    required this.details,
    required this.fineAmount,
    required this.updatedOn,
  });

  final String id;
  final String code;
  final String title;
  final RuleCategory category;
  final String summary;
  final String details;
  final double fineAmount;
  final String updatedOn;
}

enum ViolationStatus { open, appealed, appealApproved, appealRejected, paid, closed }

extension ViolationStatusLabel on ViolationStatus {
  String get label {
    switch (this) {
      case ViolationStatus.open:
        return 'Open';
      case ViolationStatus.appealed:
        return 'Appeal submitted';
      case ViolationStatus.appealApproved:
        return 'Appeal approved';
      case ViolationStatus.appealRejected:
        return 'Appeal rejected';
      case ViolationStatus.paid:
        return 'Fine paid';
      case ViolationStatus.closed:
        return 'Closed';
    }
  }
}

enum AppealStatus { pending, underReview, approved, rejected, withdrawn }

extension AppealStatusLabel on AppealStatus {
  String get label {
    switch (this) {
      case AppealStatus.pending:
        return 'Pending review';
      case AppealStatus.underReview:
        return 'Under review';
      case AppealStatus.approved:
        return 'Approved';
      case AppealStatus.rejected:
        return 'Rejected';
      case AppealStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}

class ViolationAppeal {
  const ViolationAppeal({
    required this.id,
    required this.violationId,
    required this.submittedOn,
    required this.reason,
    required this.requestedOutcome,
    required this.status,
    this.decisionNote,
    this.decidedOn,
  });

  final String id;
  final String violationId;
  final String submittedOn;
  final String reason;
  final String requestedOutcome;
  final AppealStatus status;
  final String? decisionNote;
  final String? decidedOn;

  bool get isOpen =>
      status == AppealStatus.pending || status == AppealStatus.underReview;

  ViolationAppeal copyWith({AppealStatus? status, String? decidedOn, String? decisionNote}) {
    return ViolationAppeal(
      id: id,
      violationId: violationId,
      submittedOn: submittedOn,
      reason: reason,
      requestedOutcome: requestedOutcome,
      status: status ?? this.status,
      decisionNote: decisionNote ?? this.decisionNote,
      decidedOn: decidedOn ?? this.decidedOn,
    );
  }
}

/// A violation is issued by management for breaking a community rule. It is a
/// different workflow from a resident complaint and it can carry a fine.
class Violation {
  const Violation({
    required this.id,
    required this.reference,
    required this.ruleId,
    required this.ruleTitle,
    required this.category,
    required this.issuedOn,
    required this.description,
    required this.location,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.evidenceNote = '',
  });

  final String id;
  final String reference;
  final String ruleId;
  final String ruleTitle;
  final RuleCategory category;
  final String issuedOn;
  final String description;
  final String location;
  final double amount;
  final ViolationStatus status;
  final String dueDate;
  final String evidenceNote;

  bool get canAppeal =>
      status == ViolationStatus.open && amount > 0;

  bool get isOverdue => status == ViolationStatus.open || status == ViolationStatus.appealed;

  Violation copyWith({ViolationStatus? status}) {
    return Violation(
      id: id,
      reference: reference,
      ruleId: ruleId,
      ruleTitle: ruleTitle,
      category: category,
      issuedOn: issuedOn,
      description: description,
      location: location,
      amount: amount,
      status: status ?? this.status,
      dueDate: dueDate,
      evidenceNote: evidenceNote,
    );
  }
}
