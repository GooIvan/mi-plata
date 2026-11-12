import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_type.dart';
import 'account.dart';
import 'card_installment_plan.dart';

/// Lo que se debe de una tarjeta respecto a su último corte.
///
/// No hay extractos guardados: se calcula con el saldo de la tarjeta (lo que se
/// debe hoy) y con lo que se movió *después* del último corte. Eso último es
/// lo que todavía no entra a ningún extracto; lo demás ya se cobró y es lo que
/// hay que pagar. Todo va en centavos enteros.
///
/// Los pagos y los reembolsos que llegan después del corte bajan lo que se debe
/// del extracto, como en el banco. Si se paga de más, lo que sobra queda a
/// favor para el siguiente.
///
/// Una compra diferida en cuotas baja el saldo de una vez, pero al extracto solo
/// entra una cuota por corte: lo que falta de cobrar de esas compras tampoco es
/// lo que se debe del extracto.
class CardStatement {
  const CardStatement({
    required this.statementDate,
    required this.dueDate,
    required this.debtCents,
    required this.dueCents,
  });

  /// El último corte.
  final DateTime statementDate;

  /// Hasta cuándo hay que pagar lo de ese corte.
  final DateTime dueDate;

  /// Todo lo que se debe hoy en la tarjeta, con lo que aún no entra a un
  /// extracto.
  final int debtCents;

  /// Lo que falta pagar del último corte; cero si ya está al día.
  final int dueCents;

  /// Lo que se debe pero todavía no se cobra: compras posteriores al corte.
  int get unbilledCents => debtCents - dueCents;

  bool get isPaidUp => dueCents == 0;

  /// Falta pagar algo y ya pasó la fecha límite.
  bool isOverdue(DateTime today) =>
      dueCents > 0 && dueDate.isBefore(_dateOnly(today));

  /// Cuántos días faltan para la fecha límite (negativo si ya pasó, cero si es
  /// hoy).
  int daysUntilDue(DateTime today) {
    final now = _dateOnly(today);
    return DateTime.utc(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  /// El extracto de [account] hoy, o null si no es una tarjeta con sus fechas.
  ///
  /// [sinceStatement] son los movimientos de la tarjeta hechos después del
  /// último corte; si trae de más (de antes del corte) se ignoran. [plans] son
  /// las compras en cuotas (de cualquier tarjeta: solo cuentan las de esta).
  static CardStatement? compute({
    required Account account,
    required Iterable<Transaction> sinceStatement,
    required DateTime today,
    Iterable<CardInstallmentPlan> plans = const [],
  }) {
    final calendar = account.cardCalendar;
    if (calendar == null) return null;

    final statement = calendar.lastStatement(today);
    final debt = _positive(-_cents(account.currentBalance));

    // Lo cobrado después del corte todavía no está en ningún extracto: los
    // gastos con la tarjeta y los adelantos (una transferencia que sale de
    // ella). Los pagos y reembolsos entran en lo que se debe, no aquí.
    var unbilled = 0;
    for (final transaction in sinceStatement) {
      if (!_dateOnly(transaction.date).isAfter(statement)) continue;
      if (transaction.accountId != account.id) continue;
      if (transaction.type == TransactionType.income) continue;
      unbilled += _cents(transaction.amount);
    }

    // Las compras en cuotas hechas antes del corte ya empezaron a cobrarse: lo
    // que les falta por cobrar es de extractos que vienen. (Las hechas después
    // del corte ya están arriba, completas, como cualquier gasto.)
    for (final plan in plans) {
      if (plan.accountId != account.id) continue;
      if (_dateOnly(plan.date).isAfter(statement)) continue;
      unbilled += plan.unbilledCents(calendar, statement);
    }

    return CardStatement(
      statementDate: statement,
      dueDate: calendar.paymentFor(statement),
      debtCents: debt,
      dueCents: _positive(debt - unbilled),
    );
  }

  static int _cents(double amount) => (amount * 100).round();
  static int _positive(int value) => value < 0 ? 0 : value;
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
