import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/presentation/pages/payment_success_page.dart';

void main() {
  testWidgets('a pending payment shows the verification state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: PaymentSuccessPage(
            payment: _payment(status: PaymentStatus.pendingVerification),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(find.text('Amount submitted'), findsOneWidget);
    expect(find.text('SUBMITTED ITEMS (1)'), findsOneWidget);
    expect(find.text('View Receipt'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a successful payment keeps the receipt action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: PaymentSuccessPage(
            payment: _payment(status: PaymentStatus.successful),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Successful'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Amount paid'), findsOneWidget);
    expect(find.text('View Receipt'), findsOneWidget);
  });
}

Payment _payment({required PaymentStatus status}) {
  return Payment(
    id: '1',
    invoiceNumber: 'INV-42',
    residentName: 'Resident',
    unitLabel: 'Tower A - 1205',
    items: const <InvoiceItem>[
      InvoiceItem(type: InvoiceItemType.condoFee, amount: 100, mustPaid: true),
    ],
    amount: 100,
    date: 'Nov 15, 2026',
    method: PaymentMethod.bankTransfer,
    transactionId: 'TXN-42',
    status: status,
  );
}
