import 'transaction_type.dart';

/// Un movimiento de dinero. El monto es `double` solo para mostrarlo.
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.amount,
    this.destinationAmount,
    required this.date,
    this.description,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    type: TransactionType.fromDb(json['type'] as String),
    accountId: json['account_id'] as String,
    destinationAccountId: json['destination_account_id'] as String?,
    categoryId: json['category_id'] as String?,
    amount: (json['amount'] as num).toDouble(),
    destinationAmount: (json['destination_amount'] as num?)?.toDouble(),
    date: DateTime.parse(json['transaction_date'] as String),
    description: json['description'] as String?,
  );

  final String id;
  final TransactionType type;

  /// Cuenta de la que sale el dinero (o en la que entra, si es un ingreso).
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final double amount;

  /// Lo que llega a la cuenta de destino en una transferencia entre monedas
  /// distintas. Null si llega lo mismo que sale.
  final double? destinationAmount;
  final DateTime date;
  final String? description;
}
