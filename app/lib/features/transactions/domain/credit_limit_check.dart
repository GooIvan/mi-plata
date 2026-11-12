import '../../accounts/domain/account.dart';
import 'negative_balance_check.dart';
import 'transaction.dart';
import 'transaction_draft.dart';

/// Una tarjeta que quedaría por encima de su cupo, y por cuánto.
class CreditLimitExceeded {
  const CreditLimitExceeded({required this.account, required this.overCents});

  final Account account;

  /// Cuánto se pasaría del cupo, en centavos.
  final int overCents;
}

/// Detecta los cambios que dejarían una tarjeta por encima de su cupo, para
/// avisar al usuario antes de guardar. Es un aviso, no un bloqueo: el banco
/// puede dejar pasar un poco, o el cupo puede haber cambiado.
class CreditLimitCheck {
  const CreditLimitCheck._();

  /// Las tarjetas con cupo que quedarían por encima de él por este cambio.
  ///
  /// Solo cuentan las tarjetas a las que el cambio les *suma* deuda: pagar una
  /// tarjeta que ya estaba pasada no vuelve a avisar. [draft] y [previous]
  /// significan lo mismo que en [NegativeBalanceCheck.after].
  static List<CreditLimitExceeded> after({
    required Iterable<Account> accounts,
    TransactionDraft? draft,
    Transaction? previous,
  }) {
    final results = <CreditLimitExceeded>[];

    for (final account in accounts) {
      if (account.isArchived || !account.isCard) continue;
      final limit = account.creditLimit;
      if (limit == null) continue;

      final delta =
          NegativeBalanceCheck.effectOn(account.id, draft: draft) -
          NegativeBalanceCheck.effectOn(account.id, previous: previous);
      if (delta >= 0) continue;

      final used = -((account.currentBalance * 100).round() + delta);
      final over = used - (limit * 100).round();
      if (over > 0) {
        results.add(CreditLimitExceeded(account: account, overCents: over));
      }
    }
    return results;
  }
}
