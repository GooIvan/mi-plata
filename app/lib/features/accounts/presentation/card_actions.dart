import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../domain/account.dart';
import 'accounts_providers.dart';

/// De qué cuenta se suele pagar una tarjeta: la activa, de la misma moneda y
/// que no sea otra tarjeta, con más dinero. Null si no hay ninguna.
Account? suggestedPayer(Iterable<Account> accounts, Account card) {
  Account? best;
  for (final account in accounts) {
    if (account.isArchived || account.isCard || account.id == card.id) continue;
    if (account.currency != card.currency) continue;
    if (best == null || account.currentBalance > best.currentBalance) {
      best = account;
    }
  }
  return best;
}

/// Abre el formulario de una transferencia hacia [card], para pagarla: sale de
/// la cuenta que más dinero tiene (se puede cambiar) y, si se sabe, con el
/// [amount] que se debe ya puesto.
Future<void> showPayCard(
  BuildContext context,
  WidgetRef ref,
  Account card, {
  double? amount,
}) {
  final payer = suggestedPayer(
    ref.read(accountsProvider).value ?? const [],
    card,
  );
  return showTransactionForm(
    context,
    initialType: TransactionType.transfer,
    initialAccountId: payer?.id,
    initialDestinationId: card.id,
    initialAmount: amount,
  );
}
