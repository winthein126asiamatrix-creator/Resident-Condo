import 'package:flutter/material.dart';

import '../../domain/entities/invoice.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({required this.status, super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.paid => ('Paid', const Color(0xFF087F5B)),
      InvoiceStatus.partiallyPaid => ('Part paid', const Color(0xFFB45309)),
      InvoiceStatus.pending => ('Pending', const Color(0xFFB45309)),
      InvoiceStatus.overdue => ('Overdue', const Color(0xFFC2410C)),
      InvoiceStatus.unpaid => ('Unpaid', const Color(0xFF9A5B13)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
