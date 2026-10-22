import '../../../core/format/date_format.dart';
import 'transaction_type.dart';

/// Los datos de un movimiento antes de guardarlo (al crearlo o editarlo).
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.amount,
    required this.date,
    this.description,
  });

  final TransactionType type;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;

  /// Decimal exacto en texto, como lo devuelve `AmountParser`.
  final String amount;
  final DateTime date;
  final String? description;

  /// Los nulos se envían a propósito: al editar borran lo que ya no aplica
  /// (por ejemplo, el destino al pasar de transferencia a gasto).
  Map<String, dynamic> toJson() => {
    'type': type.dbValue,
    'account_id': accountId,
    'destination_account_id': destinationAccountId,
    'category_id': categoryId,
    'amount': amount,
    'transaction_date': toDbDate(date),
    'description': description,
  };
}
