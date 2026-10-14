import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/utils/app_formatters.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../domain/entities/invoice.dart';


import '../../domain/entities/payment.dart';


import '../controllers/payment_controller.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';


import '../../../../core/theme/app_spacing.dart';


import '../../../../core/widgets/app_form_field.dart';

class PaymentMethodPage extends StatefulWidget {
  PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final PaymentController controller = Get.find<PaymentController>();
  final TextEditingController _cardNumberController = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment method'),
      body: Obx(() {
        if (controller.selectedInvoice.value == null) {
          return AppStateMessage(
            title: 'No payment selected',
            message: 'Return to an invoice to start a payment.',
            icon: Icons.credit_card_rounded,
            actionLabel: 'Back to payments',
            onAction: () => Get.offNamed(AppRoutes.home),
          );
        }
        final method = controller.selectedPaymentMethod.value;
        return ListView(
          key: Key('payment-method-scroll'),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            Text(
              'Review and confirm',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
            ),
            10.h.heightBox(),
            _ReviewCard(controller: controller),
            20.h.heightBox(),
            Text(
              'Choose how you want to pay',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            12.h.heightBox(),
            _MethodSelector(
              selected: method,
              onChanged: (value) {
                _error = '';
                controller.selectPaymentMethod(value);
              },
            ),
            18.h.heightBox(),
            if (method == PaymentMethod.card)
              _CardForm(controller: _cardNumberController)
            else if (method == PaymentMethod.bankTransfer)
              _BankTransferInfo()
            else
              _WalletInfo(),
            12.h.heightBox(),
            _DemoGatewayHint(),
            12.h.heightBox(),
            FilledButton.icon(
              key: Key('confirm-payment'),
              onPressed: controller.isPaymentProcessing.value
                  ? null
                  : () => _confirm(context),
              icon: controller.isPaymentProcessing.value
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onBrand,
                      ),
                    )
                  : Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(
                controller.isPaymentProcessing.value
                    ? 'Processing payment...'
                    : 'Confirm Payment',
              ),
              style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52)),
            ),
            if (_error.isNotEmpty) ...[
              10.h.heightBox(),
              Text(_error, style: TextStyle(color: AppPalette.danger)),
            ],
            if (controller.errorMessage.value != null) ...[
              10.h.heightBox(),
              Text(
                controller.errorMessage.value!,
                style: TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    _error = '';
    final tokens = AppThemeTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text('Confirm payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment amount',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
            3.h.heightBox(),
            Text(
              AppFormatters.currency(controller.selectedTotal),
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
            ),
            6.h.heightBox(),
            Text(
              '${controller.selectedCount} selected item'
              '${controller.selectedCount == 1 ? '' : 's'}',
              style: TextStyle(color: tokens.mutedStrong, fontSize: 12.sp),
            ),
            Divider(height: 24),
            for (final item in controller.selectedItems)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.type.label,
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(item.amount),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            12.h.heightBox(),
            Text(
              'Payment method',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
            3.h.heightBox(),
            Text(
              controller.selectedPaymentMethod.value.label,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            12.h.heightBox(),
            Text(
              'Unit',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
            3.h.heightBox(),
            Text(
              controller.selectedInvoice.value!.unitLabel,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Confirm Payment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final payment = await controller.confirmPayment(
      cardNumber: _cardNumberController.text,
    );
    if (!mounted) {
      return;
    }
    if (payment == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'Payment could not be sent.';
      });
      return;
    }
    if (payment.isSuccessful) {
      _cardNumberController.clear();
      Get.offNamed(AppRoutes.paymentSuccess, arguments: payment);
    } else {
      Get.offNamed(AppRoutes.paymentFailure, arguments: payment);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  _ReviewCard({required this.controller});
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT TO PAY',
            style: TextStyle(
              color: tokens.brandOnDark,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          6.h.heightBox(),
          Text(
            AppFormatters.currency(controller.selectedTotal),
            style: TextStyle(
              color: tokens.onBrand,
              fontSize: 27.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          6.h.heightBox(),
          Text(
            '${controller.selectedCount} of '
            '${controller.selectedInvoice.value?.unpaidItems.length ?? 0} unpaid items selected',
            style: TextStyle(color: tokens.brandOnDarkMuted, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  _MethodSelector({required this.selected, required this.onChanged});
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return RadioGroup<PaymentMethod>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      child: Column(
        children: PaymentMethod.values
            .map(
              (method) => RadioListTile<PaymentMethod>(
                value: method,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  method.label,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_description(method)),
                secondary: Icon(_icon(method), color: tokens.brand),
              ),
            )
            .toList(),
      ),
    );
  }

  String _description(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.card:
        return 'Use a saved card or enter mock card details';
      case PaymentMethod.bankTransfer:
        return 'Transfer from your linked bank account';
      case PaymentMethod.digitalWallet:
        return 'Choose a connected digital wallet';
    }
  }

  IconData _icon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.card:
        return Icons.credit_card_rounded;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.digitalWallet:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _CardForm extends StatelessWidget {
  _CardForm({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: [
        Text('Card details', style: TextStyle(fontWeight: FontWeight.w800)),
        12.h.heightBox(),
        AppTextField(
          fieldKey: Key('card-number-field'),
          label: 'Card number',
          controller: controller,
          hint: '4242 4242 4242 4242',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            LengthLimitingTextInputFormatter(19),
          ],
        ),
        AppSpacing.fieldGap.heightBox(),
        AppTextField(label: 'Name on card', icon: Icons.person_outline_rounded),
        AppSpacing.fieldGap.heightBox(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Expiry date',
                hint: 'MM/YY',
                keyboardType: TextInputType.number,
              ),
            ),
            10.w.widthBox(),
            Expanded(
              child: AppTextField(
                label: 'CVV',
                hint: '123',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemoGatewayHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppPalette.warning),
          8.w.widthBox(),
          Expanded(
            child: Text(
              'Demo gateway: a card number ending in 0000 is declined so you can '
              'check the failed payment state.',
              style: TextStyle(
                color: tokens.mutedStrong,
                fontSize: 11.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTransferInfo extends StatelessWidget {
  _BankTransferInfo();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _FormCard(
      children: [
        Icon(Icons.account_balance_rounded, color: tokens.brand, size: 32),
        10.h.heightBox(),
        Text(
          'Mock bank transfer',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        5.h.heightBox(),
        Text(
          'Transfer to the condo management account shown in your resident portal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, height: 1.4),
        ),
        12.h.heightBox(),
        Text(
          'Account ending in 4821',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _WalletInfo extends StatelessWidget {
  _WalletInfo();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _FormCard(
      children: [
        Icon(
          Icons.account_balance_wallet_rounded,
          color: tokens.brand,
          size: 32,
        ),
        10.h.heightBox(),
        Text('Connected wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        5.h.heightBox(),
        Text(
          'Alex Johnson Wallet',
          style: TextStyle(color: tokens.mutedStrong),
        ),
        8.h.heightBox(),
        Text(
          'Available balance: \$2,450.00',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(children: children),
    );
  }
}
