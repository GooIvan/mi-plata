import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(supabaseClientProvider)),
);

final transactionsProvider =
    AsyncNotifierProvider.autoDispose<TransactionsNotifier, List<Transaction>>(
      TransactionsNotifier.new,
    );

/// Movimientos recientes. Las operaciones lanzan el error si fallan, para que
/// el formulario pueda avisar al usuario.
class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  /// Cuántos movimientos recientes se piden: los que muestra el panel. La
  /// lista completa, con filtros y páginas, está en `transactionListProvider`.
  static const recentCount = 20;

  @override
  Future<List<Transaction>> build() {
    ref.watch(ledgerRevisionProvider);
    return _repository.fetchRecent(limit: recentCount);
  }

  Future<void> create(TransactionDraft draft) async {
    await _repository.create(draft);
    _refresh();
  }

  Future<void> edit(String id, TransactionDraft draft) async {
    await _repository.update(id, draft);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _refresh();
  }

  /// Los saldos, el resumen y las deudas se calculan con los movimientos: al
  /// cambiar uno, todos se recargan (ver [ledgerRevisionProvider]).
  void _refresh() => ref.read(ledgerRevisionProvider.notifier).bump();
}

/// Nombres por id, para mostrar en las listas sin consultar cada vez.
final accountNamesProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  return {for (final account in accounts) account.id: account.name};
});

/// La moneda de cada cuenta por id: un movimiento está en la de su cuenta.
final accountCurrenciesProvider = Provider.autoDispose<Map<String, String>>((
  ref,
) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  return {for (final account in accounts) account.id: account.currency};
});

final categoryNamesProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
  return {for (final category in categories) category.id: category.name};
});
