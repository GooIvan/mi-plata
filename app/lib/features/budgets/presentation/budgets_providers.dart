import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/budget_repository.dart';
import '../domain/budget_rule.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(supabaseClientProvider)),
);

final budgetRulesProvider =
    AsyncNotifierProvider.autoDispose<BudgetRulesNotifier, List<BudgetRule>>(
      BudgetRulesNotifier.new,
    );

/// Las reglas de presupuesto. Las operaciones lanzan el error si fallan, para
/// que el formulario pueda avisar al usuario.
class BudgetRulesNotifier extends AsyncNotifier<List<BudgetRule>> {
  BudgetRepository get _repository => ref.read(budgetRepositoryProvider);

  @override
  Future<List<BudgetRule>> build() => _repository.fetchAll();

  /// El presupuesto de la categoría pasa a ser [amount] desde [month].
  Future<void> setBudget({
    required String categoryId,
    required DateTime month,
    required String amount,
  }) async {
    await _repository.set(categoryId: categoryId, month: month, amount: amount);
    ref.invalidateSelf();
  }

  /// La categoría queda sin presupuesto desde [month].
  Future<void> clearBudget({
    required String categoryId,
    required DateTime month,
  }) => setBudget(categoryId: categoryId, month: month, amount: '0');
}
