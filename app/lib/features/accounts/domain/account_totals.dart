import '../../currency/domain/converted_total.dart';
import '../../currency/domain/currency_converter.dart';
import 'account.dart';

/// Dinero total repartido en las cuentas.
///
/// Las tarjetas de crédito no cuentan en el dinero total: lo que se gasta con
/// ellas todavía no salió de ninguna cuenta, así que ese dinero sigue en las
/// otras cuentas hasta que se paga la tarjeta. Lo que se debe en las tarjetas
/// se suma aparte (ver [cardDebtCentsByCurrency]).
class AccountTotals {
  const AccountTotals._();

  /// Suma los saldos por moneda, en centavos enteros para no acumular el
  /// error del punto flotante. Las cuentas con saldo negativo (un sobregiro)
  /// restan; las tarjetas no cuentan.
  static Map<String, int> centsByCurrency(Iterable<Account> accounts) {
    final totals = <String, int>{};
    for (final account in accounts) {
      if (account.isCard) continue;
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
  ) => _toBase(centsByCurrency(accounts), converter);

  /// Lo que se debe en las tarjetas, por moneda y en centavos enteros. Cada
  /// tarjeta cuenta por separado: el saldo a favor de una no paga la deuda de
  /// otra. Las monedas sin deuda no aparecen.
  static Map<String, int> cardDebtCentsByCurrency(Iterable<Account> accounts) {
    final debts = <String, int>{};
    for (final account in accounts) {
      if (!account.isCard) continue;
      final owed = -(account.currentBalance * 100).round();
      if (owed <= 0) continue;
      debts.update(account.currency, (debt) => debt + owed, ifAbsent: () => owed);
    }
    return debts;
  }

  /// Lo que se debe en las tarjetas, pasado a la moneda base. Las monedas sin
  /// tasa no se suman: quedan en [ConvertedTotal.missing].
  static ConvertedTotal cardDebtInBase(
    Iterable<Account> accounts,
    CurrencyConverter converter,
  ) => _toBase(cardDebtCentsByCurrency(accounts), converter);

  static ConvertedTotal _toBase(
    Map<String, int> centsByCurrency,
    CurrencyConverter converter,
  ) {
    var cents = 0;
    final missing = <String>{};
    for (final MapEntry(key: currency, value: total) in centsByCurrency.entries) {
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
