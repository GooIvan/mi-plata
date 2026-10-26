import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../data/savings_goal_repository.dart';
import '../domain/goal_draft.dart';
import '../domain/goal_progress.dart';
import '../domain/savings_goal.dart';

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>(
  (ref) => SavingsGoalRepository(ref.watch(supabaseClientProvider)),
);

final savingsGoalsProvider =
    AsyncNotifierProvider.autoDispose<SavingsGoalsNotifier, List<SavingsGoal>>(
      SavingsGoalsNotifier.new,
    );

/// Las metas de ahorro. Las operaciones lanzan el error si fallan, para que el
/// formulario pueda avisar al usuario.
class SavingsGoalsNotifier extends AsyncNotifier<List<SavingsGoal>> {
  SavingsGoalRepository get _repository =>
      ref.read(savingsGoalRepositoryProvider);

  @override
  Future<List<SavingsGoal>> build() => _repository.fetchAll();

  Future<void> create(GoalDraft draft) async {
    await _repository.create(draft);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, GoalDraft draft) async {
    await _repository.update(id, draft);
    ref.invalidateSelf();
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _repository.setArchived(id, isArchived: isArchived);
    ref.invalidateSelf();
  }
}

/// Cada meta con lo que lleva ahorrado (el saldo de su cuenta). Se recalcula
/// sola cuando cambian las metas o las cuentas, y las cuentas cambian con cada
/// movimiento.
final goalProgressProvider = FutureProvider.autoDispose<List<GoalProgress>>((
  ref,
) async {
  final goals = await ref.watch(savingsGoalsProvider.future);
  final accounts = await ref.watch(accountsProvider.future);
  final byId = {for (final account in accounts) account.id: account};

  return [
    for (final goal in goals)
      if (byId[goal.accountId] case final account?)
        GoalProgress(
          goal: goal,
          accountName: account.name,
          currency: account.currency,
          balanceCents: (account.currentBalance * 100).round(),
          accountArchived: account.isArchived,
        ),
  ];
});

/// Los últimos movimientos de la cuenta de una meta: lo que se ha ido
/// ahorrando (y sacando).
final goalHistoryProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, accountId) {
      ref.watch(ledgerRevisionProvider);
      return ref
          .watch(transactionRepositoryProvider)
          .fetchPage(
            filter: TransactionFilter(accountId: accountId),
            offset: 0,
            limit: 10,
          );
    });
