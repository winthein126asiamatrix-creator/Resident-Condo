import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Payment method')),
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
          key: const Key('payment-method-scroll'),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            const Text(
              'Review and confirm',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _ReviewCard(controller: controller),
            const SizedBox(height: 20),
            Text(
              'Choose how you want to pay',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _MethodSelector(
              selected: method,
              onChanged: (value) {
                _error = '';
                controller.selectPaymentMethod(value);
              },
            ),
            const SizedBox(height: 18),
            if (method == PaymentMethod.card)
              _CardForm(controller: _cardNumberController)
            else if (method == PaymentMethod.bankTransfer)
              const _BankTransferInfo()
            else
              const _WalletInfo(),
            const SizedBox(height: 12),
            _DemoGatewayHint(),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('confirm-payment'),
              onPressed: controller.isPaymentProcessing.value
                  ? null
                  : () => _confirm(context),
              icon: controller.isPaymentProcessing.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(
                controller.isPaymentProcessing.value
                    ? 'Processing payment...'
                    : 'Confirm Payment',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: AppPalette.danger)),
            ],
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    _error = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment amount',
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              AppFormatters.currency(controller.selectedTotal),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.selectedCount} selected item'
              '${controller.selectedCount == 1 ? '' : 's'}',
              style: const TextStyle(color: AppPalette.mutedStrong, fontSize: 12),
            ),
            const Divider(height: 24),
            for (final item in controller.selectedItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.type.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(item.amount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Payment method',
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              controller.selectedPaymentMethod.value.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Unit',
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              controller.selectedInvoice.value!.unitLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Payment'),
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
  const _ReviewCard({required this.controller});
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AMOUNT TO PAY',
            style: TextStyle(
              color: AppPalette.brandOnDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormatters.currency(controller.selectedTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${controller.selectedCount} of '
            '${controller.selectedInvoice.value?.unpaidItems.length ?? 0} unpaid items selected',
            style: const TextStyle(
              color: AppPalette.brandOnDarkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.selected, required this.onChanged});
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  method.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_description(method)),
                secondary: Icon(_icon(method), color: AppPalette.brand),
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
  const _CardForm({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: [
        const Text('Card details', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('card-number-field'),
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Card number',
            hintText: '4242 4242 4242 4242',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            LengthLimitingTextInputFormatter(19),
          ],
        ),
        const SizedBox(height: 10),
        const TextField(
          decoration: InputDecoration(labelText: 'Name on card'),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Expiry date'))),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(labelText: 'CVV'),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppPalette.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo gateway: a card number ending in 0000 is declined so you can '
              'check the failed payment state.',
              style: TextStyle(
                color: AppPalette.mutedStrong,
                fontSize: 11,
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
  const _BankTransferInfo();

  @override
  Widget build(BuildContext context) {
    return const _FormCard(
      children: [
        Icon(Icons.account_balance_rounded, color: AppPalette.brand, size: 32),
        SizedBox(height: 10),
        Text('Mock bank transfer', style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text(
          'Transfer to the condo management account shown in your resident portal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.muted, height: 1.4),
        ),
        SizedBox(height: 12),
        Text('Account ending in 4821', style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WalletInfo extends StatelessWidget {
  const _WalletInfo();

  @override
  Widget build(BuildContext context) {
    return const _FormCard(
      children: [
        Icon(
          Icons.account_balance_wallet_rounded,
          color: AppPalette.brand,
          size: 32,
        ),
        SizedBox(height: 10),
        Text('Connected wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('Alex Johnson Wallet', style: TextStyle(color: AppPalette.mutedStrong)),
        SizedBox(height: 8),
        Text(
          'Available balance: \$2,450.00',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(children: children),
    );
  }
}
