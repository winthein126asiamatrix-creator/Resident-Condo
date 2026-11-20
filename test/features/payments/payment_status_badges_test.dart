import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/presentation/widgets/payment_status_badge.dart';

void main() {
  Future<void> pumpBadges(
    WidgetTester tester, {
    required InvoiceStatus status,
    required bool overdue,
  }) {
    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: PaymentStatusBadges(status: status, overdue: overdue),
          ),
        ),
      ),
    );
  }

  testWidgets('an overdue unpaid invoice shows Unpaid then Overdue', (
    tester,
  ) async {
    await pumpBadges(tester, status: InvoiceStatus.unpaid, overdue: true);

    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Unpaid')).dy,
      lessThan(tester.getTopLeft(find.text('Overdue')).dy),
    );
  });

  testWidgets('an overdue partial invoice shows Partial then Overdue', (
    tester,
  ) async {
    await pumpBadges(
      tester,
      status: InvoiceStatus.partiallyPaid,
      overdue: true,
    );

    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('a paid invoice shows only Paid', (tester) async {
    await pumpBadges(tester, status: InvoiceStatus.paid, overdue: false);

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('a cancelled invoice shows only Cancelled', (tester) async {
    await pumpBadges(tester, status: InvoiceStatus.cancelled, overdue: false);

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('an API overdue status is not duplicated', (tester) async {
    await pumpBadges(tester, status: InvoiceStatus.overdue, overdue: true);

    expect(find.text('Overdue'), findsOneWidget);
  });
}
