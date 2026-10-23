import '../../currency/domain/converted_total.dart';
import '../../currency/domain/currency_converter.dart';
import 'debt.dart';
import 'debt_direction.dart';

class DebtTotals {
  const DebtTotals._();

  /// Lo que falta por pagar (si debo) o por cobrar (si me deben), pasado a la
  /// moneda base, en centavos.
  ///
  /// Solo cuentan las deudas no archivadas; una deuda saldada aporta cero. Las
  /// de una moneda sin tasa no se suman y quedan en `missing`. En centavos
  /// enteros para no acumular error de coma flotante.
  static ConvertedTotal remaining(
    Iterable<Debt> debts,
    DebtDirection direction,
    CurrencyConverter converter,
  ) {
    final byCurrency = <String, int>{};
    for (final debt in debts) {
      if (debt.isArchived || debt.direction != direction) continue;
      final cents = (debt.remaining * 100).round();
      if (cents > 0) {
        byCurrency.update(debt.currency, (sum) => sum + cents, ifAbsent: () => cents);
      }
    }

    var total = 0;
    final missing = <String>{};
    for (final MapEntry(key: currency, value: cents) in byCurrency.entries) {
      final converted = converter.toBaseCents(cents, currency);
      if (converted == null) {
        missing.add(currency);
      } else {
        total += converted;
      }
    }
    return ConvertedTotal(cents: total, missing: missing);
  }
}
