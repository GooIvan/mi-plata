import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../data/card_installment_repository.dart';
import '../domain/account.dart';
import '../domain/card_installment_draft.dart';
import '../domain/card_installment_plan.dart';
import '../domain/card_statement.dart';
import 'accounts_providers.dart';

final cardInstallmentRepositoryProvider = Provider<CardInstallmentRepository>(
  (ref) => CardInstallmentRepository(ref.watch(supabaseClientProvider)),
);

/// Las compras diferidas en cuotas con tarjeta. Se recargan solas cuando cambia
/// algo del dinero (ver [ledgerRevisionProvider]).
final cardInstallmentPlansProvider =
    FutureProvider.autoDispose<List<CardInstallmentPlan>>((ref) {
      ref.watch(ledgerRevisionProvider);
      return ref.watch(cardInstallmentRepositoryProvider).fetchAll();
    });

/// Registra una compra diferida en cuotas y avisa de que el dinero cambió: el
/// saldo de la tarjeta, el resumen y los extractos se recalculan.
Future<void> createCardInstallmentPurchase(
  WidgetRef ref,
  CardInstallmentDraft draft,
) async {
  await ref.read(cardInstallmentRepositoryProvider).createPurchase(draft);
  ref.read(ledgerRevisionProvider.notifier).bump();
}

/// Cuántos movimientos de una tarjeta se piden desde el último corte. Un mes de
/// uso de una tarjeta cabe de sobra.
const _maxSinceStatement = 1000;

/// El extracto de una tarjeta: lo que debe de su último corte. Null si la
/// cuenta no existe o no tiene sus fechas. Se recalcula solo cuando cambia
/// algo del dinero (las cuentas se recargan con cada movimiento).
final cardStatementProvider = FutureProvider.autoDispose
    .family<CardStatement?, String>((ref, accountId) async {
      final accounts = await ref.watch(accountsProvider.future);
      final account = accounts.where((a) => a.id == accountId).firstOrNull;
      final calendar = account?.cardCalendar;
      if (account == null || calendar == null) return null;

      final plans = await ref.watch(cardInstallmentPlansProvider.future);
      final today = DateTime.now();
      final statement = calendar.lastStatement(today);
      final moves = await ref
          .watch(transactionRepositoryProvider)
          .fetchPage(
            filter: TransactionFilter(
              accountId: accountId,
              from: DateTime(
                statement.year,
                statement.month,
                statement.day + 1,
              ),
            ),
            offset: 0,
            limit: _maxSinceStatement,
          );
      return CardStatement.compute(
        account: account,
        sinceStatement: moves,
        today: today,
        plans: plans,
      );
    });

/// Una tarjeta con lo que debe de su último corte.
typedef CardDue = ({Account account, CardStatement statement});

/// Las tarjetas activas que tienen algo por pagar de su último corte, la más
/// urgente primero (las vencidas, y luego por fecha límite).
final cardDuesProvider = FutureProvider.autoDispose<List<CardDue>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final dues = <CardDue>[];
  for (final account in accounts) {
    if (account.isArchived || account.cardCalendar == null) continue;
    final statement = await ref.watch(cardStatementProvider(account.id).future);
    if (statement != null && !statement.isPaidUp) {
      dues.add((account: account, statement: statement));
    }
  }
  dues.sort((a, b) => a.statement.dueDate.compareTo(b.statement.dueDate));
  return dues;
});
