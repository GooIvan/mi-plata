/// "Desde este mes, el presupuesto de esta categoría es X": una fila de
/// `budgets`. Vale hasta que otra regla de un mes posterior lo cambie; un
/// monto de cero significa "sin presupuesto desde este mes".
class BudgetRule {
  const BudgetRule({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.cents,
  });

  factory BudgetRule.fromJson(Map<String, dynamic> json) => BudgetRule(
    id: json['id'] as String,
    categoryId: json['category_id'] as String,
    month: DateTime.parse(json['effective_month'] as String),
    cents: ((json['amount'] as num) * 100).round(),
  );

  final String id;
  final String categoryId;

  /// El primer día del mes desde el que rige.
  final DateTime month;
  final int cents;
}
