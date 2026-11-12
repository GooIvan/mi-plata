import '../../../core/format/date_format.dart';

/// Los datos de una compra diferida en cuotas antes de registrarla.
class CardInstallmentDraft {
  const CardInstallmentDraft({
    required this.accountId,
    required this.purchaseAmount,
    required this.installments,
    this.installmentAmount,
    this.categoryId,
    required this.date,
    this.description,
  });

  final String accountId;

  /// Lo que costaba la compra, como decimal exacto en texto.
  final String purchaseAmount;
  final int installments;

  /// Lo que vale cada cuota, con intereses; null si no hay intereses.
  final String? installmentAmount;
  final String? categoryId;
  final DateTime date;
  final String? description;

  /// Los parámetros de la función `create_card_installment_purchase`.
  Map<String, dynamic> toRpcParams() => {
    'p_account_id': accountId,
    'p_purchase_amount': purchaseAmount,
    'p_installments': installments,
    'p_installment_amount': installmentAmount,
    'p_category_id': categoryId,
    'p_date': toDbDate(date),
    'p_description': description,
  };
}
