import 'debt.dart';
import 'debt_direction.dart';

class DebtTotals {
  const DebtTotals._();

  /// Lo que falta por pagar (si debo) o por cobrar (si me deben), en centavos.
  ///
  /// Solo cuentan las deudas no archivadas de [currency]; una deuda saldada
  /// aporta cero. En centavos enteros para no acumular error de coma flotante.
  static int remainingCents(
    Iterable<Debt> debts,
    DebtDirection direction, {
    String currency = 'COP',
  }) {
    var total = 0;
    for (final debt in debts) {
      if (debt.isArchived ||
          debt.direction != direction ||
          debt.currency != currency) {
        continue;
      }
      final cents = (debt.remaining * 100).round();
      if (cents > 0) total += cents;
    }
    return total;
  }
}
