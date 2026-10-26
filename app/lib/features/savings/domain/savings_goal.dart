/// "Quiero juntar X en esta cuenta (para esta fecha)": una fila de
/// `savings_goals`.
///
/// La meta no guarda cuánto se lleva: eso es el saldo de su cuenta (ver
/// `GoalProgress`). El monto está en la moneda de la cuenta.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.accountId,
    required this.isArchived,
    this.targetDate,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetCents: ((json['target_amount'] as num) * 100).round(),
    accountId: json['account_id'] as String,
    isArchived: json['is_archived'] as bool,
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date'] as String),
  );

  final String id;
  final String name;
  final int targetCents;
  final String accountId;
  final bool isArchived;

  /// Para cuándo se quiere tener la plata; sin fecha, la meta no tiene prisa.
  final DateTime? targetDate;
}
