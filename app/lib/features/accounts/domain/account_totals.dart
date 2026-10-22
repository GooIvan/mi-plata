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
}
