import 'package:flutter/material.dart';

import '../../domain/entities/payment.dart';

/// Status pill for a settled payment record (used in history and receipts).
class PaymentRecordBadge extends StatelessWidget {
  const PaymentRecordBadge({required this.status, super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaymentStatus.successful => ('Paid', const Color(0xFF087F5B)),
      PaymentStatus.failed => ('Failed', const Color(0xFFC2410C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
