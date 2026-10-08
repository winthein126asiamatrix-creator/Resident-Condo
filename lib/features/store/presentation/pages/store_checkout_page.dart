import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../features/session/presentation/controllers/session_controller.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/store_product.dart';
import '../controllers/store_controller.dart';
import '../widgets/store_cards.dart';
import '../widgets/store_widgets.dart';

/// Delivery method, delivery slot, how to settle the Store Fee, then review and
/// place the order. Nothing is created until the resident confirms here.
class StoreCheckoutPage extends GetView<StoreController> {
  const StoreCheckoutPage({super.key});

  /// The windows a resident can choose from for either delivery method.
  static const _slots = <String, List<String>>{
    'Deliver to Doorstep': [
      'Today · 6:00 PM – 7:00 PM',
      'Today · 7:00 PM – 8:00 PM',
      'Tomorrow · 8:00 AM – 9:00 AM',
    ],
    'Pick-up at Lobby': [
      'Today · 5:00 PM – 6:00 PM',
      'Today · 6:00 PM – 7:00 PM',
      'Tomorrow · 9:00 AM – 10:00 AM',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Checkout'),
      body: Obx(() {
        if (controller.cart.isEmpty) {
          return AppStateMessage(
            title: 'Nothing to check out',
            message: 'Your basket is empty. Add something from the store first.',
            icon: Icons.shopping_basket_outlined,
            actionLabel: 'Back to the store',
            onAction: () => Get.back<void>(),
          );
        }
        return ListView(
          key: const Key('store-checkout-scroll'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _Section(
              title: 'Delivery method',
              child: Column(
                children: [
                  for (final method in StoreDeliveryMethod.values)
                    _DeliveryOption(
                      key: Key('store-delivery-${method.name}'),
                      method: method,
                      selected: controller.deliveryMethod.value == method,
                      onTap: () => controller.selectDeliveryMethod(method),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Delivery time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.deliveryLocation,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in _slots[
                          controller.deliveryMethod.value.label] ??
                          const <String>[])
                        ChoiceChip(
                          key: Key('store-slot-$slot'),
                          label: Text(slot),
                          selected: slot == controller.deliveryTime.value,
                          onSelected: (_) => controller.selectDeliveryTime(slot),
                          selectedColor: tokens.brandOnDark,
                          labelStyle: TextStyle(
                            color: slot == controller.deliveryTime.value
                                ? tokens.brand
                                : tokens.mutedStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'How would you like to pay?',
              child: Column(
                children: [
                  for (final choice in StorePaymentChoice.values)
                    _DeliveryOption(
                      key: Key('store-payment-${choice.name}'),
                      method: choice == StorePaymentChoice.payNow
                          ? StoreDeliveryMethod.doorstep
                          : StoreDeliveryMethod.lobbyPickup,
                      selected: controller.paymentChoice.value == choice,
                      title: choice == StorePaymentChoice.payNow
                          ? 'Pay now at checkout'
                          : 'Add to my statement',
                      description: choice == StorePaymentChoice.payNow
                          ? 'The store fee is settled straight away.'
                          : 'The store fee appears on your statement, next to '
                                'your other charges.',
                      onTap: () => controller.selectPaymentChoice(choice),
                    ),
                ],
              ),
            ),
            // Paying now needs a method before the button can say what it
            // charges, so the list only appears for that choice.
            if (controller.paymentChoice.value == StorePaymentChoice.payNow) ...[
              const SizedBox(height: 16),
              _Section(
                title: 'Payment method',
                child: _PaymentMethodPicker(controller: controller),
              ),
            ],
            const SizedBox(height: 16),
            const StoreFeeNotice(),
            const SizedBox(height: 16),
            _Section(
              title: 'Your items',
              child: Column(
                children: [
                  for (final line in controller.cart) StoreOrderLineRow(line: line),
                ],
              ),
            ),
            const SizedBox(height: 16),
            StoreCheckoutSummaryCard(
              keyName: 'store-checkout-summary',
              subtotal: controller.cartSubtotal,
              deliveryFee: controller.deliveryFee,
              total: controller.cartTotal,
              itemCount: controller.cartCount,
            ),
            const SizedBox(height: 20),
            // The button states the exact amount and the method, so there is no
            // second guessing about what is about to be charged. Paying now
            // needs a method, and the button stays out of reach until one is
            // picked rather than failing silently.
            Obx(
              () {
                final method = controller.selectedMethod.value;
                final payingNow = controller.paymentChoice.value ==
                        StorePaymentChoice.payNow;
                final busy =
                    controller.isSubmitting.value || controller.isPaying.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPrimaryAction(
                      key: const Key('store-place-order'),
                      onPressed: busy || (payingNow && method == null)
                          ? null
                          : () => _place(context),
                      isLoading: busy,
                      label: _actionLabel,
                      icon: payingNow
                          ? Icons.lock_rounded
                          : Icons.receipt_long_rounded,
                    ),
                    if (payingNow && method == null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Choose a payment method to continue.',
                        key: Key('store-method-required'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }

  /// What the primary action will actually do, in the resident's own words.
  String get _actionLabel {
    final total = AppFormatters.currency(controller.cartTotal);
    if (controller.isPaying.value) {
      return 'Processing payment...';
    }
    final method = controller.selectedMethod.value;
    if (controller.paymentChoice.value == StorePaymentChoice.payNow &&
        method != null) {
      return 'Pay $total via ${method.buttonLabel}';
    }
    return 'Place order · $total';
  }

  Future<void> _place(BuildContext context) {
    return controller.paymentChoice.value == StorePaymentChoice.payNow
        ? _pay(context)
        : _review(context);
  }

  /// Takes the Store Fee first, then places the order as already paid.
  ///
  /// The order is only created after the gateway confirms, so a declined
  /// attempt leaves no half-placed order behind.
  Future<void> _pay(BuildContext context) async {
    final method = controller.selectedMethod.value;
    if (method == null) {
      return;
    }
    final total = controller.cartTotal;
    final confirmed = await showAppConfirmSummaryDialog(
      context,
      title: 'Confirm payment',
      message: 'Check the amount before paying.',
      icon: storePaymentMethodIcon(method),
      summary: [
        AppSummaryRow(
          label: 'Store Fee',
          value: AppFormatters.currency(total),
          emphasis: true,
        ),
        AppSummaryRow(label: 'Method', value: method.label),
        AppSummaryRow(
          label: 'Saved as',
          value: controller.selectedSavedMethod.value?.title ?? 'New payment',
        ),
        AppSummaryRow(
          label: 'Delivery',
          value: controller.deliveryMethod.value.label,
        ),
      ],
      confirmLabel: 'Pay ${AppFormatters.currency(total)}',
      pendingLabel: 'Processing...',
      onConfirm: () async {
        final order = await controller.checkout(
          residentName: _residentName,
          unitLabel: controller.deliveryLocation,
          method: method,
        );
        if (order == null) {
          return AppConfirmResult.failure(
            controller.errorMessage.value ?? 'This payment could not be taken.',
          );
        }
        return const AppConfirmResult.success();
      },
    );
    if (!confirmed) {
      return;
    }
    _goToOrder();
  }

  /// The resident on the session, or a sensible stand-in when there is none.
  String get _residentName {
    if (!Get.isRegistered<SessionController>()) {
      return 'Alex Johnson';
    }
    return Get.find<SessionController>().name;
  }

  void _goToOrder() {
    final order = controller.selectedOrder.value;
    if (order != null) {
      // Replace checkout with the order rather than clearing the stack, so the
      // store stays underneath and the back button still leads home. Using
      // `offAllNamed` here would make this page the root route and leave the
      // resident with nowhere to go back to.
      Get.offNamed<void>(AppRoutes.storeOrderDetail, arguments: order);
    }
  }

  /// Review step. The order is only created after this confirmation.
  Future<void> _review(BuildContext context) async {
    final confirmed = await showAppConfirmSummaryDialog(
      context,
      title: 'Confirm store order',
      message: 'Please review your order before placing it.',
      icon: Icons.storefront_rounded,
      summary: [
        AppSummaryRow(
          label: 'Items',
          value: '${controller.cartCount} item${controller.cartCount == 1 ? '' : 's'}',
        ),
        AppSummaryRow(
          label: 'Delivery',
          value: controller.deliveryMethod.value.label,
        ),
        AppSummaryRow(label: 'When', value: controller.deliveryTime.value),
        AppSummaryRow(
          label: 'Store Fee',
          value: AppFormatters.currency(controller.cartTotal),
          emphasis: true,
        ),
      ],
      confirmLabel: 'Place order',
      pendingLabel: 'Placing...',
      onConfirm: () async {
        final order = await controller.checkout(
          residentName: _residentName,
          unitLabel: controller.deliveryLocation,
        );
        if (order == null) {
          return AppConfirmResult.failure(
            controller.errorMessage.value ?? 'Unable to place this order.',
          );
        }
        return const AppConfirmResult.success();
      },
    );
    if (!confirmed) {
      return;
    }
    _goToOrder();
  }
}

/// Saved methods first, then the full list of ways to pay.
///
/// Saved methods are the shortcut and the full list is the fallback, so a
/// resident who has paid before is one tap from done and a resident who has not
/// is never blocked.
class _PaymentMethodPicker extends StatelessWidget {
  const _PaymentMethodPicker({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (StoreController.savedMethods.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Saved',
              style: TextStyle(
                color: tokens.faint,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (final saved in StoreController.savedMethods)
            _MethodRow(
              key: Key('store-method-saved-${saved.id}'),
              icon: storePaymentMethodIcon(saved.method),
              title: saved.title,
              description: saved.subtitle,
              selected: controller.selectedSavedMethod.value?.id == saved.id,
              onTap: () => controller.selectMethod(
                saved.method,
                saved: saved,
              ),
            ),
          const SizedBox(height: 14),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'All methods',
            style: TextStyle(
              color: tokens.faint,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        for (final method in StorePaymentMethod.values)
          _MethodRow(
            key: Key('store-method-${method.name}'),
            icon: storePaymentMethodIcon(method),
            title: method.label,
            description: method.description,
            // A plain method row is only selected when no saved one is, so the
            // two lists never both look picked.
            selected: controller.selectedSavedMethod.value == null &&
                controller.selectedMethod.value == method,
            onTap: () => controller.selectMethod(method),
          ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? tokens.brandTint : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? tokens.brand : tokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tokens.surface : tokens.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? tokens.brand : tokens.mutedStrong,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected ? tokens.brand : tokens.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: tokens.brand,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.method,
    required this.selected,
    required this.onTap,
    this.title,
    this.description,
    super.key,
  });

  /// Only used for the icon when the row is a payment choice rather than a
  /// delivery method.
  final StoreDeliveryMethod method;
  final bool selected;
  final VoidCallback onTap;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final label = title ?? method.label;
    final detail = description ?? method.description;
    final icon = switch (method) {
      StoreDeliveryMethod.doorstep => Icons.door_front_door_outlined,
      StoreDeliveryMethod.lobbyPickup => Icons.storefront_outlined,
    };
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? tokens.brandTint : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? tokens.brand : tokens.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? tokens.brand : tokens.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? tokens.brand : tokens.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: tokens.brand,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
