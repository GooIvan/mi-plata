import 'account_type.dart';

/// Una cuenta con su saldo, tal como lo calcula la vista `v_account_balances`.
///
/// Los montos son `double` solo para mostrarlos: los cálculos se hacen en la
/// base de datos con `numeric(14,2)` y al guardar se envían como texto.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    required this.currentBalance,
    required this.isArchived,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.fromDb(json['type'] as String),
    currency: json['currency'] as String,
    initialBalance: (json['initial_balance'] as num).toDouble(),
    currentBalance: (json['current_balance'] as num).toDouble(),
    isArchived: json['is_archived'] as bool,
  );

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final double initialBalance;
  final double currentBalance;
  final bool isArchived;
}
