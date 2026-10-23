import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_type.dart';
import 'transaction.dart';
import 'transaction_draft.dart';
import 'transaction_type.dart';

/// Una cuenta que quedaría con saldo negativo, y con cuánto.
class NegativeBalance {
  const NegativeBalance({required this.account, required this.balance});

  final Account account;
  final double balance;
}

/// Detecta los cambios que dejarían una cuenta en negativo, para avisar al
/// usuario antes de guardar. Es un aviso, no un bloqueo: el saldo puede ser
/// negativo de verdad (sobregiro) o estar desfasado respecto a lo anotado.
class NegativeBalanceCheck {
  const NegativeBalanceCheck._();

  /// Las cuentas que quedarían en negativo por este cambio.
  ///
  /// - [draft] es lo que se va a guardar; null al eliminar un movimiento.
  /// - [previous] es el movimiento tal como estaba; null al crear uno.
  ///
  /// Solo cuentan las cuentas a las que el cambio les *resta* dinero, y las
  /// tarjetas quedan exentas porque para ellas el negativo es lo normal.
  /// Se calcula en centavos enteros para no acumular error de coma flotante.
  static List<NegativeBalance> after({
    required Iterable<Account> accounts,
    TransactionDraft? draft,
    Transaction? previous,
  }) {
    final results = <NegativeBalance>[];

    for (final account in accounts) {
      if (account.isArchived || account.type == AccountType.card) continue;

      final delta =
          _effect(account.id, draft: draft) -
          _effect(account.id, previous: previous);
      if (delta >= 0) continue;

      final newCents = _cents(account.currentBalance) + delta;
      if (newCents < 0) {
        results.add(NegativeBalance(account: account, balance: newCents / 100));
      }
    }
    return results;
  }

  /// Cuánto suma (o resta) un movimiento al saldo de [accountId], en centavos.
  static int _effect(
    String accountId, {
    TransactionDraft? draft,
    Transaction? previous,
  }) {
    final TransactionType type;
    final String sourceId;
    final String? destinationId;
    final int cents;
    // Lo que llega al destino: en una transferencia entre monedas distintas no
    // es lo mismo que lo que sale.
    final int destinationCents;

    if (draft != null) {
      type = draft.type;
      sourceId = draft.accountId;
      destinationId = draft.destinationAccountId;
      cents = _cents(double.parse(draft.amount));
      destinationCents = draft.destinationAmount == null
          ? cents
          : _cents(double.parse(draft.destinationAmount!));
    } else if (previous != null) {
      type = previous.type;
      sourceId = previous.accountId;
      destinationId = previous.destinationAccountId;
      cents = _cents(previous.amount);
      destinationCents = previous.destinationAmount == null
          ? cents
          : _cents(previous.destinationAmount!);
    } else {
      return 0;
    }

    var total = 0;
    if (sourceId == accountId) {
      total += type == TransactionType.income ? cents : -cents;
    }
    if (type == TransactionType.transfer && destinationId == accountId) {
      total += destinationCents;
    }
    return total;
  }

  static int _cents(double amount) => (amount * 100).round();
}
