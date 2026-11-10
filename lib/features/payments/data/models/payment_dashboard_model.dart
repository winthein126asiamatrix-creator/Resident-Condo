import '../../domain/entities/payment_dashboard.dart';

/// Parsed `GET /api/v1/payments/dashboard` response.
class PaymentDashboardModel extends PaymentDashboard {
  const PaymentDashboardModel({
    required super.outstandingBalance,
    required super.feeSummary,
    required super.paymentStatistics,
    required super.invoiceSummary,
    required super.recentInvoices,
    required super.recentPayments,
  });

  static PaymentDashboardModel parse(Object? json) {
    if (json is! Map) {
      return const PaymentDashboardModel(
        outstandingBalance: OutstandingBalanceModel(amount: 0, currency: ''),
        feeSummary: <FeeSummaryModel>[],
        paymentStatistics: PaymentStatisticsModel(
          currentMonthDue: 0,
          lastPayment: 0,
          paidThisYear: 0,
        ),
        invoiceSummary: InvoiceSummaryModel(
          total: 0,
          unpaid: 0,
          partial: 0,
          paid: 0,
        ),
        recentInvoices: <RecentInvoiceModel>[],
        recentPayments: <RecentPaymentModel>[],
      );
    }
    // Some endpoints wrap the body in `data` or `result`; the dashboard itself
    // is flat.
    final nested = json['data'] is Map
        ? json['data'] as Map
        : json['result'] is Map
        ? json['result'] as Map
        : json;
    return PaymentDashboardModel.fromJson(Map<String, dynamic>.from(nested));
  }

  factory PaymentDashboardModel.fromJson(Map<String, dynamic> json) {
    final balanceJson = json['outstanding_balance'];
    final statisticsJson = json['payment_statistics'];
    final invoiceSummaryJson = json['invoice_summary'];

    return PaymentDashboardModel(
      outstandingBalance: balanceJson is Map
          ? OutstandingBalanceModel.fromJson(
              Map<String, dynamic>.from(balanceJson),
            )
          : const OutstandingBalanceModel(amount: 0, currency: ''),
      feeSummary: _maps(json['fee_summary'])
          .map(FeeSummaryModel.fromJson)
          .toList(growable: false),
      paymentStatistics: statisticsJson is Map
          ? PaymentStatisticsModel.fromJson(
              Map<String, dynamic>.from(statisticsJson),
            )
          : const PaymentStatisticsModel(
              currentMonthDue: 0,
              lastPayment: 0,
              paidThisYear: 0,
            ),
      invoiceSummary: invoiceSummaryJson is Map
          ? InvoiceSummaryModel.fromJson(
              Map<String, dynamic>.from(invoiceSummaryJson),
            )
          : const InvoiceSummaryModel(total: 0, unpaid: 0, partial: 0, paid: 0),
      recentInvoices: _maps(json['recent_invoices'])
          .map(RecentInvoiceModel.fromJson)
          .toList(growable: false),
      recentPayments: _maps(json['recent_payments'])
          .map(RecentPaymentModel.fromJson)
          .toList(growable: false),
    );
  }

  /// Serializes a dashboard that did not come from [PaymentDashboardModel].
  ///
  /// The API path already returns a model, so this is only the type-safe
  /// fallback used when a plain entity is handed to the cache.
  factory PaymentDashboardModel.fromEntity(PaymentDashboard dashboard) {
    if (dashboard is PaymentDashboardModel) {
      return dashboard;
    }
    return PaymentDashboardModel(
      outstandingBalance: OutstandingBalanceModel(
        amount: dashboard.outstandingBalance.amount,
        currency: dashboard.outstandingBalance.currency,
      ),
      feeSummary: dashboard.feeSummary
          .map(
            (fee) => FeeSummaryModel(
              feeType: fee.feeType,
              label: fee.label,
              amount: fee.amount,
            ),
          )
          .toList(growable: false),
      paymentStatistics: PaymentStatisticsModel(
        currentMonthDue: dashboard.paymentStatistics.currentMonthDue,
        lastPayment: dashboard.paymentStatistics.lastPayment,
        paidThisYear: dashboard.paymentStatistics.paidThisYear,
      ),
      invoiceSummary: InvoiceSummaryModel(
        total: dashboard.invoiceSummary.total,
        unpaid: dashboard.invoiceSummary.unpaid,
        partial: dashboard.invoiceSummary.partial,
        paid: dashboard.invoiceSummary.paid,
      ),
      recentInvoices: dashboard.recentInvoices
          .map(
            (invoice) => RecentInvoiceModel(
              id: invoice.id,
              invoiceNumber: invoice.invoiceNumber,
              billingPeriod: invoice.billingPeriod,
              totalAmount: invoice.totalAmount,
              paidAmount: invoice.paidAmount,
              remainingAmount: invoice.remainingAmount,
              status: invoice.status,
              dueDate: invoice.dueDate,
            ),
          )
          .toList(growable: false),
      recentPayments: dashboard.recentPayments
          .map(
            (payment) => RecentPaymentModel(
              id: payment.id,
              paymentNumber: payment.paymentNumber,
              amount: payment.amount,
              currency: payment.currency,
              paidAt: payment.paidAt,
              status: payment.status,
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'outstanding_balance': <String, dynamic>{
      'amount': outstandingBalance.amount,
      'currency': outstandingBalance.currency,
    },
    'fee_summary': feeSummary
        .map(
          (fee) => <String, dynamic>{
            'fee_type': fee.feeType,
            'label': fee.label,
            'amount': fee.amount,
          },
        )
        .toList(),
    'payment_statistics': <String, dynamic>{
      'current_month_due': paymentStatistics.currentMonthDue,
      'last_payment': paymentStatistics.lastPayment,
      'paid_this_year': paymentStatistics.paidThisYear,
    },
    'invoice_summary': <String, dynamic>{
      'total': invoiceSummary.total,
      'unpaid': invoiceSummary.unpaid,
      'partial': invoiceSummary.partial,
      'paid': invoiceSummary.paid,
    },
    'recent_invoices': recentInvoices
        .map(
          (invoice) => <String, dynamic>{
            'id': invoice.id,
            'invoice_number': invoice.invoiceNumber,
            'billing_period': invoice.billingPeriod,
            'total_amount': invoice.totalAmount,
            'paid_amount': invoice.paidAmount,
            'remaining_amount': invoice.remainingAmount,
            'status': invoice.status,
            'due_date': invoice.dueDate?.toIso8601String(),
          },
        )
        .toList(),
    'recent_payments': recentPayments
        .map(
          (payment) => <String, dynamic>{
            'id': payment.id,
            'payment_number': payment.paymentNumber,
            'amount': payment.amount,
            'currency': payment.currency,
            'paid_at': payment.paidAt?.toIso8601String(),
            'status': payment.status,
          },
        )
        .toList(),
  };
}

class OutstandingBalanceModel extends OutstandingBalance {
  const OutstandingBalanceModel({
    required super.amount,
    required super.currency,
  });

  factory OutstandingBalanceModel.fromJson(Map<String, dynamic> json) {
    return OutstandingBalanceModel(
      amount: _asDouble(json['amount']),
      currency: _asString(json['currency']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'currency': currency,
  };
}

class FeeSummaryModel extends FeeSummary {
  const FeeSummaryModel({
    required super.feeType,
    required super.label,
    required super.amount,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      feeType: _asString(json['fee_type']),
      label: _asString(json['label']),
      amount: _asDouble(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fee_type': feeType,
    'label': label,
    'amount': amount,
  };
}

class PaymentStatisticsModel extends PaymentStatistics {
  const PaymentStatisticsModel({
    required super.currentMonthDue,
    required super.lastPayment,
    required super.paidThisYear,
  });

  factory PaymentStatisticsModel.fromJson(Map<String, dynamic> json) {
    return PaymentStatisticsModel(
      currentMonthDue: _asDouble(json['current_month_due']),
      lastPayment: _asDouble(json['last_payment']),
      paidThisYear: _asDouble(json['paid_this_year']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'current_month_due': currentMonthDue,
    'last_payment': lastPayment,
    'paid_this_year': paidThisYear,
  };
}

class InvoiceSummaryModel extends InvoiceSummary {
  const InvoiceSummaryModel({
    required super.total,
    required super.unpaid,
    required super.partial,
    required super.paid,
  });

  factory InvoiceSummaryModel.fromJson(Map<String, dynamic> json) {
    return InvoiceSummaryModel(
      total: _asInt(json['total']),
      unpaid: _asInt(json['unpaid']),
      partial: _asInt(json['partial']),
      paid: _asInt(json['paid']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'unpaid': unpaid,
    'partial': partial,
    'paid': paid,
  };
}

class RecentInvoiceModel extends RecentInvoice {
  const RecentInvoiceModel({
    required super.id,
    required super.invoiceNumber,
    required super.billingPeriod,
    required super.totalAmount,
    required super.paidAmount,
    required super.remainingAmount,
    required super.status,
    super.dueDate,
  });

  factory RecentInvoiceModel.fromJson(Map<String, dynamic> json) {
    return RecentInvoiceModel(
      id: _asInt(json['id']),
      invoiceNumber: _asString(json['invoice_number']),
      billingPeriod: _asString(json['billing_period']),
      totalAmount: _asDouble(json['total_amount']),
      paidAmount: _asDouble(json['paid_amount']),
      remainingAmount: _asDouble(json['remaining_amount']),
      status: _asString(json['status']),
      dueDate: _asDate(json['due_date']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'invoice_number': invoiceNumber,
    'billing_period': billingPeriod,
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'status': status,
    'due_date': dueDate?.toIso8601String(),
  };
}

class RecentPaymentModel extends RecentPayment {
  const RecentPaymentModel({
    required super.id,
    required super.paymentNumber,
    required super.amount,
    required super.currency,
    required super.paidAt,
    required super.status,
  });

  factory RecentPaymentModel.fromJson(Map<String, dynamic> json) {
    return RecentPaymentModel(
      id: _asInt(json['id']),
      paymentNumber: _asString(json['payment_number']),
      amount: _asDouble(json['amount']),
      currency: _asString(json['currency']),
      paidAt: _asDate(json['paid_at']),
      status: _asString(json['status']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'payment_number': paymentNumber,
    'amount': amount,
    'currency': currency,
    'paid_at': paidAt?.toIso8601String(),
    'status': status,
  };
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String _asString(Object? value) => value is String
    ? value
    : (value == null || value == false ? '' : value.toString());

DateTime? _asDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value.trim());
}
