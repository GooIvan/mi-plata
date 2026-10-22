/// Un abono: el movimiento que pagó (o cobró) parte de una deuda.
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.transactionId,
    required this.amount,
    required this.date,
    required this.accountId,
    this.description,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
    id: json['id'] as String,
    debtId: json['debt_id'] as String,
    transactionId: json['transaction_id'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['transaction_date'] as String),
    accountId: json['account_id'] as String,
    description: json['description'] as String?,
  );

  final String id;
  final String debtId;

  /// El movimiento asociado; al eliminarlo, el abono desaparece.
  final String transactionId;
  final double amount;
  final DateTime date;
  final String accountId;
  final String? description;
}
