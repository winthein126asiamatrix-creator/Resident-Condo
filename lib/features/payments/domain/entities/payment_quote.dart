/// One priced line in a payment quote.
class PaymentQuoteItem {
  const PaymentQuoteItem({required this.id, required this.amount});

  final int id;
  final double amount;
}

/// The backend's authoritative price for the selected invoice lines.
///
/// A quote is only usable while it is not expired, belongs to the invoice the
/// resident is paying, and prices exactly the fees they selected. The backend's
/// total is used as-is; it is never recomputed from the local selection.
class PaymentQuote {
  const PaymentQuote({
    required this.quoteId,
    required this.invoiceId,
    required this.totalAmount,
    required this.currency,
    required this.expiresAt,
    required this.items,
  });

  final String quoteId;
  final int invoiceId;
  final double totalAmount;
  final String currency;
  final DateTime? expiresAt;
  final List<PaymentQuoteItem> items;

  /// True once the expiry instant has passed. Comparisons are done on the
  /// parsed instants, so a UTC `expires_at` is compared correctly on a device
  /// in another time zone.
  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  /// Returns a resident-facing reason the quote cannot be paid, or null when
  /// every required condition holds.
  String? validationError({
    required int invoiceId,
    required Set<int> selectedItemIds,
  }) {
    if (quoteId.trim().isEmpty) {
      return 'The payment quote is incomplete. Please try again.';
    }
    if (this.invoiceId != invoiceId) {
      return 'The payment quote does not match this invoice. Please try again.';
    }
    if (totalAmount <= 0) {
      return 'The payment quote has no amount to pay. Please try again.';
    }
    if (currency.trim().isEmpty) {
      return 'The payment quote has no currency. Please try again.';
    }
    if (expiresAt == null) {
      return 'The payment quote has no expiry time. Please try again.';
    }
    if (isExpired) {
      return 'This payment quote has expired. Confirm again to get a new one.';
    }
    final quotedIds = items.map((item) => item.id).toSet();
    if (items.isEmpty ||
        items.length != quotedIds.length ||
        quotedIds.length != selectedItemIds.length ||
        !quotedIds.containsAll(selectedItemIds)) {
      return 'The payment quote does not match the selected fees. '
          'Please try again.';
    }
    return null;
  }
}
