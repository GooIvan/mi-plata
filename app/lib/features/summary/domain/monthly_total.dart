import '../../transactions/domain/transaction_type.dart';

/// Una fila de `v_monthly_totals`: cuánto se ingresó o gastó en un mes,
/// en una categoría y una moneda. El total es `double` solo para leerlo; los
/// cálculos del resumen se hacen en centavos enteros.
class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.currency,
    required this.type,
    required this.categoryId,
    required this.total,
    required this.movements,
  });

  factory MonthlyTotal.fromJson(Map<String, dynamic> json) => MonthlyTotal(
    month: DateTime.parse(json['month'] as String),
    currency: json['currency'] as String,
    type: TransactionType.fromDb(json['type'] as String),
    categoryId: json['category_id'] as String?,
    total: (json['total'] as num).toDouble(),
    movements: (json['movements'] as num).toInt(),
  );

  /// El primer día del mes.
  final DateTime month;
  final String currency;

  /// Solo `income` o `expense`: las transferencias no están en la vista.
  final TransactionType type;

  /// Null cuando los movimientos no tienen categoría.
  final String? categoryId;
  final double total;
  final int movements;
}
