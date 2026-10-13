import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/payment.dart';

/// Status pill for a settled payment record (used in history and receipts).
class PaymentRecordBadge extends StatelessWidget {
  PaymentRecordBadge({required this.status, super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaymentStatus.successful => ('Paid', Color(0xFF087F5B)),
      PaymentStatus.failed => ('Failed', Color(0xFFC2410C)),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w800),
      ),
    );
  }
}
