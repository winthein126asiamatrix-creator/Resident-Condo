import 'dart:ui';

import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/payment.dart';

extension InvoiceStatusLabel on InvoiceStatus {
  String get label => switch (this) {
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.partiallyPaid => 'Partial',
    InvoiceStatus.pending => 'Pending',
    InvoiceStatus.overdue => 'Overdue',
    InvoiceStatus.unpaid => 'Unpaid',
    InvoiceStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    InvoiceStatus.paid => const Color(0xFF087F5B),
    InvoiceStatus.partiallyPaid => const Color(0xFFB45309),
    InvoiceStatus.pending => const Color(0xFFB45309),
    InvoiceStatus.overdue => const Color(0xFFC2410C),
    InvoiceStatus.unpaid => const Color(0xFF9A5B13),
    InvoiceStatus.cancelled => const Color(0xFF6B7280),
  };
}


extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.successful => 'Paid',
    PaymentStatus.failed => 'Failed',
    PaymentStatus.pendingVerification => 'Pending',
    PaymentStatus.unknown => 'Unknown',
  };

  Color get color => switch (this) {
    PaymentStatus.successful => const Color(0xFF087F5B),
    PaymentStatus.failed => const Color(0xFFC2410C),
    PaymentStatus.pendingVerification => const Color(0xFFB45309),
    PaymentStatus.unknown => const Color(0xFF6B7280),
  };
}