import 'account_type.dart';
import 'card_calendar.dart';

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
    this.creditLimit,
    this.statementDay,
    this.paymentDay,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.fromDb(json['type'] as String),
    currency: json['currency'] as String,
    initialBalance: (json['initial_balance'] as num).toDouble(),
    currentBalance: (json['current_balance'] as num).toDouble(),
    isArchived: json['is_archived'] as bool,
    creditLimit: (json['credit_limit'] as num?)?.toDouble(),
    statementDay: (json['statement_day'] as num?)?.toInt(),
    paymentDay: (json['payment_day'] as num?)?.toInt(),
  );

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final double initialBalance;
  final double currentBalance;
  final bool isArchived;

  /// El cupo de una tarjeta; null si no se dio (o si no es una tarjeta).
  final double? creditLimit;

  /// El día del mes en que cierra el extracto de una tarjeta, y el día hasta el
  /// que hay que pagarlo. Van juntos: o están los dos o ninguno.
  final int? statementDay;
  final int? paymentDay;

  bool get isCard => type == AccountType.card;

  /// Las fechas de la tarjeta, si se dieron.
  CardCalendar? get cardCalendar => isCard && statementDay != null && paymentDay != null
      ? CardCalendar(statementDay: statementDay!, paymentDay: paymentDay!)
      : null;
}
