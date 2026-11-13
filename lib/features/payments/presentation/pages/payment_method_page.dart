import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/network/api_config.dart';

import '../../../../core/services/photo_picker.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../domain/entities/invoice.dart';

import '../../domain/entities/payment_method_option.dart';

import '../controllers/payment_controller.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/widgets/app_form_field.dart';

import '../../../../core/widgets/app_image_preview.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({this.photoPicker, super.key});

  final PhotoPicker? photoPicker;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final PaymentController controller = Get.find<PaymentController>();
  final TextEditingController _cardNumberController = TextEditingController();
  AttachedPhoto? _proof;
  String _error = '';

  @override
  void initState() {
    super.initState();
    controller.loadPaymentMethods();
  }

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

        final methods = controller.paymentMethods;
        if (controller.isLoadingPaymentMethods.value && methods.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        final methodsError = controller.paymentMethodsError.value;
        if (methodsError != null && methods.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load payment methods',
            message: methodsError,
            icon: Icons.account_balance_wallet_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadPaymentMethods,
          );
        }

        final method = controller.selectedPaymentMethod;
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
            if (controller.isShowingCachedPaymentMethods.value) ...[
              10.h.heightBox(),
              _CachedMethodsNotice(
                updatedAt: controller.paymentMethodsUpdatedLabel,
              ),
            ],
            20.h.heightBox(),
            Text(
              'Choose how you want to pay',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            12.h.heightBox(),
            if (methods.isEmpty)
              AppStateMessage(
                title: 'No payment methods',
                message: 'There are no payment methods available right now.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else
              _MethodSelector(
                methods: methods,
                selectedKey: controller.selectedPaymentMethodKey.value,
                onChanged: (value) {
                  setState(() {
                    _error = '';
                    _proof = null;
                  });
                  controller.selectPaymentMethod(value);
                },
              ),
            18.h.heightBox(),
            if (method != null) ...[
              if (method.code.trim().toLowerCase() == 'card')
                _CardForm(controller: _cardNumberController),
              if (method.hasBankDetails) _BankDetails(method: method),
              if (method.hasQrImage) ...[
                if (method.hasBankDetails) 12.h.heightBox(),
                _QrImageCard(method: method),
              ],
              if (method.hasInstructions) ...[
                if (method.hasBankDetails || method.hasQrImage)
                  12.h.heightBox(),
                _InstructionsCard(method: method),
              ],
              if (method.requiresProof) ...[
                if (method.hasBankDetails ||
                    method.hasQrImage ||
                    method.hasInstructions)
                  12.h.heightBox(),
                _ProofSection(
                  proof: _proof,
                  onAttach: _attachProof,
                  onRemove: () => setState(() => _proof = null),
                ),
              ],
            ],
            12.h.heightBox(),
            if (method != null && method.code.trim().toLowerCase() == 'card')
              _DemoGatewayHint(),
            12.h.heightBox(),
            FilledButton.icon(
              key: Key('confirm-payment'),
              onPressed: controller.isPaymentProcessing.value || method == null
                  ? null
                  : () {
                      vibrateNow();
                      _confirm(context);
                    },
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

  Future<void> _attachProof() async {
    final source = await _choosePhotoSource();
    if (source == null || !mounted) {
      return;
    }
    final picker = widget.photoPicker ?? const DevicePhotoPicker();
    final result = await picker.pick(source);
    if (!mounted) {
      return;
    }
    final photo = result.photo;
    if (photo != null) {
      setState(() => _proof = photo);
      return;
    }
    final error = result.error;
    if (error != null) {
      showAppFeedback(
        context,
        title: 'Could not attach proof',
        message: error,
        isError: true,
      );
    }
  }

  Future<ImageSource?> _choosePhotoSource() {
    final tokens = AppThemeTokens.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            10.h.heightBox(),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            6.h.heightBox(),
            ListTile(
              key: Key('payment-proof-source-gallery'),
              leading: Icon(Icons.photo_library_outlined, color: tokens.brand),
              title: Text(
                'Choose from gallery',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pick an existing proof photo',
                style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              key: Key('payment-proof-source-camera'),
              leading: Icon(Icons.photo_camera_outlined, color: tokens.brand),
              title: Text(
                'Take a photo',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Use your camera to capture proof',
                style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            12.h.heightBox(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    _error = '';
    final method = controller.selectedPaymentMethod;
    if (method == null) {
      setState(() => _error = 'Choose a payment method first.');
      return;
    }
    if (method.requiresProof && _proof == null) {
      setState(() => _error = 'Attach proof of payment to continue.');
      return;
    }

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
              method.displayName,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_proof != null) ...[
              12.h.heightBox(),
              Text(
                'Proof attached',
                style: TextStyle(color: tokens.muted, fontSize: 12.sp),
              ),
              3.h.heightBox(),
              Text(_proof!.name, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
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
      proofPath: _proof?.path,
      proofFileName: _proof?.name,
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

class _CachedMethodsNotice extends StatelessWidget {
  const _CachedMethodsNotice({required this.updatedAt});

  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final suffix = updatedAt.isEmpty ? '' : ' Last updated $updatedAt.';
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.offline_pin_outlined, size: 18, color: AppPalette.warning),
          8.w.widthBox(),
          Expanded(
            child: Text(
              'Showing saved payment methods.$suffix',
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

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.methods,
    required this.selectedKey,
    required this.onChanged,
  });

  final List<PaymentMethodOption> methods;
  final String? selectedKey;
  final ValueChanged<PaymentMethodOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return RadioGroup<String>(
      groupValue: selectedKey,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        for (final method in methods) {
          if (method.methodKey == value && method.isActive) {
            onChanged(method);
            return;
          }
        }
      },
      child: Column(
        children: methods
            .map(
              (method) => RadioListTile<String>(
                value: method.methodKey,
                enabled: method.isActive,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  method.displayName,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_description(method)),
                secondary: Icon(
                  _icon(method),
                  color: method.isActive ? tokens.brand : tokens.faint,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _description(PaymentMethodOption method) {
    if (!method.isActive) {
      return 'Unavailable';
    }
    final parts = <String>[];
    if (method.bankName.trim().isNotEmpty) {
      parts.add(method.bankName.trim());
    }
    if (method.accountNumber.trim().isNotEmpty) {
      parts.add('Account ${method.accountNumber.trim()}');
    }
    if (method.currency.trim().isNotEmpty) {
      parts.add(method.currency.trim());
    }
    if (method.requiresProof) {
      parts.add('Proof required');
    }
    return parts.isEmpty ? 'Tap to choose' : parts.join(' · ');
  }

  IconData _icon(PaymentMethodOption method) {
    if (!method.isActive) {
      return Icons.block_rounded;
    }
    if (method.hasQrImage) {
      return Icons.qr_code_2_rounded;
    }
    if (method.hasBankDetails) {
      return Icons.account_balance_outlined;
    }
    return Icons.payments_outlined;
  }
}

class _CardForm extends StatelessWidget {
  const _CardForm({required this.controller});
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

class _BankDetails extends StatelessWidget {
  const _BankDetails({required this.method});

  final PaymentMethodOption method;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _FormCard(
      children: [
        Icon(Icons.account_balance_rounded, color: tokens.brand, size: 32),
        10.h.heightBox(),
        Text(
          method.displayName,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        if (method.bankName.trim().isNotEmpty) ...[
          10.h.heightBox(),
          _DetailLine(label: 'Bank', value: method.bankName.trim()),
        ],
        if (method.accountName.trim().isNotEmpty)
          _DetailLine(label: 'Account name', value: method.accountName.trim()),
        if (method.accountNumber.trim().isNotEmpty)
          _DetailLine(
            label: 'Account number',
            value: method.accountNumber.trim(),
          ),
      ],
    );
  }
}

class _QrImageCard extends StatelessWidget {
  const _QrImageCard({required this.method});

  final PaymentMethodOption method;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final url = _resolveQrUrl(method.qrImageUrl);
    return _FormCard(
      children: [
        Text('Scan to pay', style: TextStyle(fontWeight: FontWeight.w800)),
        10.h.heightBox(),
        Container(
          width: 190,
          height: 190,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: tokens.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            key: Key('payment-method-qr'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _QrFallback(
              icon: Icons.qr_code_2_rounded,
              label: 'QR code unavailable',
            ),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return _QrFallback(
                icon: Icons.qr_code_2_rounded,
                label: 'Loading QR code',
              );
            },
          ),
        ),
      ],
    );
  }

  static String _resolveQrUrl(String value) {
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      return raw;
    }
    try {
      final base = Uri.parse(ApiConfig.baseUrl);
      return base.resolve(raw).toString();
    } on StateError {
      return raw;
    }
  }
}

class _QrFallback extends StatelessWidget {
  const _QrFallback({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: tokens.faint),
          8.h.heightBox(),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.method});

  final PaymentMethodOption method;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _FormCard(
      children: [
        Icon(Icons.info_outline_rounded, color: tokens.brand, size: 28),
        8.h.heightBox(),
        Text(
          'Payment instructions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        6.h.heightBox(),
        Text(
          method.instructions.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _ProofSection extends StatelessWidget {
  const _ProofSection({
    required this.proof,
    required this.onAttach,
    required this.onRemove,
  });

  final AttachedPhoto? proof;
  final VoidCallback onAttach;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _FormCard(
      children: [
        Icon(Icons.receipt_long_outlined, color: tokens.brand, size: 30),
        8.h.heightBox(),
        Text('Proof of payment', style: TextStyle(fontWeight: FontWeight.w800)),
        5.h.heightBox(),
        Text(
          'This payment method requires a photo or screenshot of your transfer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted, height: 1.4),
        ),
        12.h.heightBox(),
        if (proof == null)
          OutlinedButton.icon(
            key: Key('payment-proof-attach'),
            onPressed: onAttach,
            icon: Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text('Attach proof'),
          )
        else ...[
          AppImagePreview(path: proof!.path, caption: proof!.name, height: 150),
          8.h.heightBox(),
          TextButton.icon(
            key: Key('payment-proof-remove'),
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded, size: 18),
            label: Text('Remove proof'),
          ),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
          ),
          10.w.widthBox(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
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
