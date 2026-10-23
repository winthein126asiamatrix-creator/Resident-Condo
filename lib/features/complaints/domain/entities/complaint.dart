import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ComplaintCategory {
  noise,
  cleanliness,
  parking,
  security,
  commonArea,
  pets,
  utilities,
  other,
}

extension ComplaintCategoryLabel on ComplaintCategory {
  String get label {
    switch (this) {
      case ComplaintCategory.noise:
        return 'rulesCategoryNoise'.tr;
      case ComplaintCategory.cleanliness:
        return 'Cleanliness';
      case ComplaintCategory.parking:
        return 'rulesCategoryParking'.tr;
      case ComplaintCategory.security:
        return 'Security';
      case ComplaintCategory.commonArea:
        return 'Common areas';
      case ComplaintCategory.pets:
        return 'rulesCategoryPets'.tr;
      case ComplaintCategory.utilities:
        return 'Utilities';
      case ComplaintCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintCategory.noise:
        return Icons.volume_up_rounded;
      case ComplaintCategory.cleanliness:
        return Icons.cleaning_services_rounded;
      case ComplaintCategory.parking:
        return Icons.local_parking_rounded;
      case ComplaintCategory.security:
        return Icons.security_rounded;
      case ComplaintCategory.commonArea:
        return Icons.apartment_rounded;
      case ComplaintCategory.pets:
        return Icons.pets_rounded;
      case ComplaintCategory.utilities:
        return Icons.bolt_rounded;
      case ComplaintCategory.other:
        return Icons.more_horiz_rounded;
    }
  }
}

enum ComplaintStatus { submitted, inReview, actionTaken, resolved, withdrawn }

extension ComplaintStatusLabel on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.submitted:
        return 'Submitted';
      case ComplaintStatus.inReview:
        return 'In review';
      case ComplaintStatus.actionTaken:
        return 'Action taken';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}

enum ComplaintPriority { low, medium, high }

extension ComplaintPriorityLabel on ComplaintPriority {
  String get label {
    switch (this) {
      case ComplaintPriority.low:
        return 'Low';
      case ComplaintPriority.medium:
        return 'Medium';
      case ComplaintPriority.high:
        return 'High';
    }
  }
}

class ComplaintComment {
  const ComplaintComment({
    required this.author,
    required this.authorRole,
    required this.message,
    required this.postedOn,
  });

  final String author;
  final String authorRole;
  final String message;
  final String postedOn;
}

/// A complaint is a resident raised grievance. It is tracked separately from
/// community rule violations, which are issued by management.
class Complaint {
  const Complaint({
    required this.id,
    required this.reference,
    required this.category,
    required this.subject,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    required this.createdOn,
    required this.updatedOn,
    required this.comments,
    this.isAnonymous = false,
    this.assignedTo,
    this.resolution,
  });

  final String id;
  final String reference;
  final ComplaintCategory category;
  final String subject;
  final String description;
  final String location;
  final ComplaintPriority priority;
  final ComplaintStatus status;
  final String createdOn;
  final String updatedOn;
  final List<ComplaintComment> comments;
  final bool isAnonymous;
  final String? assignedTo;
  final String? resolution;

  bool get isOpen =>
      status != ComplaintStatus.resolved && status != ComplaintStatus.withdrawn;

  bool get canWithdraw => status == ComplaintStatus.submitted;

  Complaint copyWith({
    ComplaintStatus? status,
    String? updatedOn,
    List<ComplaintComment>? comments,
    String? resolution,
  }) {
    return Complaint(
      id: id,
      reference: reference,
      category: category,
      subject: subject,
      description: description,
      location: location,
      priority: priority,
      status: status ?? this.status,
      createdOn: createdOn,
      updatedOn: updatedOn ?? this.updatedOn,
      comments: comments ?? this.comments,
      isAnonymous: isAnonymous,
      assignedTo: assignedTo,
      resolution: resolution ?? this.resolution,
    );
  }
}
