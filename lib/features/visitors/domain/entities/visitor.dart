import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum VisitorStatus { preRegistered, checkedIn, checkedOut, cancelled, expired }

extension VisitorStatusLabel on VisitorStatus {
  String get label {
    switch (this) {
      case VisitorStatus.preRegistered:
        return 'Pre-registered';
      case VisitorStatus.checkedIn:
        return 'Checked in';
      case VisitorStatus.checkedOut:
        return 'Checked out';
      case VisitorStatus.cancelled:
        return 'Cancelled';
      case VisitorStatus.expired:
        return 'Expired';
    }
  }

  bool get isActive =>
      this == VisitorStatus.preRegistered || this == VisitorStatus.checkedIn;
}

enum VisitorRelation {
  family,
  friend,
  colleague,
  delivery,
  serviceProvider,
  other,
}

extension VisitorRelationLabel on VisitorRelation {
  String get label {
    switch (this) {
      case VisitorRelation.family:
        return 'relationFamily'.tr;
      case VisitorRelation.friend:
        return 'relationFriend'.tr;
      case VisitorRelation.colleague:
        return 'relationColleague'.tr;
      case VisitorRelation.delivery:
        return 'relationDelivery'.tr;
      case VisitorRelation.serviceProvider:
        return 'relationServiceProvider'.tr;
      case VisitorRelation.other:
        return 'relationOther'.tr;
    }
  }

  IconData get icon {
    switch (this) {
      case VisitorRelation.family:
        return Icons.family_restroom_rounded;
      case VisitorRelation.friend:
        return Icons.people_outline_rounded;
      case VisitorRelation.colleague:
        return Icons.work_outline_rounded;
      case VisitorRelation.delivery:
        return Icons.local_shipping_outlined;
      case VisitorRelation.serviceProvider:
        return Icons.build_circle_outlined;
      case VisitorRelation.other:
        return Icons.person_outline_rounded;
    }
  }
}

class Visitor {
  const Visitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.purpose,
    required this.date,
    required this.arrivalWindow,
    required this.status,
    required this.accessCode,
    required this.registeredBy,
    required this.registeredOn,
    this.vehiclePlate,
    this.notes = '',
    this.checkedInAt,
    this.checkedOutAt,
  });

  final String id;
  final String name;
  final String phone;
  final VisitorRelation relation;
  final String purpose;
  final String date;

  /// Human readable window such as `2:00 PM – 4:00 PM`.
  final String arrivalWindow;
  final VisitorStatus status;

  /// Alphanumeric lobby code. No QR code is used in the visitor workflow.
  final String accessCode;
  final String registeredBy;
  final String registeredOn;
  final String? vehiclePlate;
  final String notes;
  final String? checkedInAt;
  final String? checkedOutAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get canCheckIn =>
      status == VisitorStatus.preRegistered ||
      status == VisitorStatus.checkedOut;

  bool get canCheckOut => status == VisitorStatus.checkedIn;

  Visitor copyWith({
    VisitorStatus? status,
    String? checkedInAt,
    String? checkedOutAt,
  }) {
    return Visitor(
      id: id,
      name: name,
      phone: phone,
      relation: relation,
      purpose: purpose,
      date: date,
      arrivalWindow: arrivalWindow,
      status: status ?? this.status,
      accessCode: accessCode,
      registeredBy: registeredBy,
      registeredOn: registeredOn,
      vehiclePlate: vehiclePlate,
      notes: notes,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
    );
  }
}

/// Result of validating an access code typed at the lobby desk.
class VisitorVerification {
  const VisitorVerification({
    required this.isValid,
    required this.message,
    this.visitor,
  });

  final bool isValid;
  final String message;
  final Visitor? visitor;
}