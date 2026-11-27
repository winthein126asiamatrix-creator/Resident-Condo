import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/invoice.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({required this.status, super.key, this.backgroundColor});

  final InvoiceStatus status;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.paid => ('Paid', Color(0xFF087F5B)),
      InvoiceStatus.partiallyPaid => ('Partial', Color(0xFFB45309)),
      InvoiceStatus.pending => ('Pending', Color(0xFFB45309)),
      InvoiceStatus.overdue => ('Overdue', Color(0xFFC2410C)),
      InvoiceStatus.unpaid => ('Unpaid', Color(0xFF9A5B13)),
      InvoiceStatus.cancelled => ('Cancelled', Color(0xFF6B7280)),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor??color.withValues(alpha: 0.12),
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

/// The original payment status badge followed by an extra Overdue badge.
///
/// The API status is never replaced: an unpaid invoice past due shows both
/// `Unpaid` and `Overdue`, and a partially paid one shows `Partial` and
/// `Overdue`. Paid and cancelled invoices only ever show their own status.
class PaymentStatusBadges extends StatelessWidget {
  const PaymentStatusBadges({
    required this.status,
    required this.overdue,
    super.key,
  });

  final InvoiceStatus status;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final showOverdue = overdue && status != InvoiceStatus.overdue;
    if (!showOverdue) {
      return PaymentStatusBadge(status: status);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PaymentStatusBadge(status: status),
        const SizedBox(height: 6),
        const PaymentStatusBadge(status: InvoiceStatus.overdue),
      ],
    );
  }
}
