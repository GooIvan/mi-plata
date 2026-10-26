import '../../currency/domain/converted_total.dart';
import '../../currency/domain/currency_converter.dart';
import 'account.dart';

/// Dinero total repartido en las cuentas.
class AccountTotals {
  const AccountTotals._();

  /// Suma los saldos por moneda, en centavos enteros para no acumular el
  /// error del punto flotante. Las cuentas con deuda (saldo negativo) restan.
  static Map<String, int> centsByCurrency(Iterable<Account> accounts) {
    final totals = <String, int>{};
    for (final account in accounts) {
      final cents = (account.currentBalance * 100).round();
      totals.update(
        account.currency,
        (total) => total + cents,
        ifAbsent: () => cents,
      );
    }
    return totals;
  }

  /// El dinero total pasado a la moneda base. Las monedas sin tasa no se
  /// suman: quedan en [ConvertedTotal.missing] para avisarlo.
  static ConvertedTotal inBase(
    Iterable<Account> accounts,
    CurrencyConverter converter,
  ) {
    var cents = 0;
    final missing = <String>{};
    for (final MapEntry(key: currency, value: total)
        in centsByCurrency(accounts).entries) {
      final converted = converter.toBaseCents(total, currency);
      if (converted == null) {
        missing.add(currency);
      } else {
        cents += converted;
      }
    }
    return ConvertedTotal(cents: cents, missing: missing);
  }
}
