import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test/core/theme/app_theme_tokens.dart';

import '../../domain/entities/invoice.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({required this.status, super.key, this.backgroundColor});

  final InvoiceStatus status;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.brandOnDark,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: tokens.brand,
                    fontSize: 10.sp,
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
    super.key,
  });

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
      return PaymentStatusBadge(status: status);
    
  }
}
