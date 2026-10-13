import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/invoice.dart';

class PaymentStatusBadge extends StatelessWidget {
  PaymentStatusBadge({required this.status, super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.paid => ('Paid', Color(0xFF087F5B)),
      InvoiceStatus.partiallyPaid => ('Partial', Color(0xFFB45309)),
      InvoiceStatus.pending => ('Pending', Color(0xFFB45309)),
      InvoiceStatus.overdue => ('Overdue', Color(0xFFC2410C)),
      InvoiceStatus.unpaid => ('Unpaid', Color(0xFF9A5B13)),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
