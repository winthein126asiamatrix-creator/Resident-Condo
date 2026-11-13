class PaymentMethodOption {
  const PaymentMethodOption({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.requiresProof,
    this.accountName = '',
    this.accountNumber = '',
    this.bankName = '',
    this.qrImageUrl = '',
    this.instructions = '',
    this.currency = '',
  });

  final int id;
  final String code;
  final String name;
  final String accountName;
  final String accountNumber;
  final String bankName;
  final String qrImageUrl;
  final String instructions;
  final String currency;
  final bool isActive;
  final bool requiresProof;

  String get methodKey {
    final normalizedCode = code.trim();
    if (normalizedCode.isNotEmpty) {
      return 'code:$normalizedCode';
    }
    return 'id:$id';
  }

  String get displayName {
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      return 'Payment method';
    }
    final words = normalizedCode
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  bool get hasBankDetails =>
      bankName.trim().isNotEmpty ||
      accountName.trim().isNotEmpty ||
      accountNumber.trim().isNotEmpty;

  bool get hasQrImage => qrImageUrl.trim().isNotEmpty;

  bool get hasInstructions => instructions.trim().isNotEmpty;
}

class CachedPaymentMethods {
  const CachedPaymentMethods({required this.methods, required this.updatedAt});

  final List<PaymentMethodOption> methods;
  final DateTime updatedAt;
}
