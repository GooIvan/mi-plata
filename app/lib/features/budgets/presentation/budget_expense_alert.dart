import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/presentation/summary_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_draft.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/budget_calculator.dart';
import 'budget_ui.dart';
import 'budgets_providers.dart';

/// El aviso que corresponde a guardar [draft], o null si no hay nada que decir.
///
/// Debe llamarse ANTES de guardar: compara lo ya gastado en el mes con lo que
/// se va a sumar. Es un extra y nunca estorba: si algo falla (sin conexión, sin
/// datos), simplemente no hay aviso y el movimiento se guarda igual.
///
/// Al editar un gasto de la misma categoría y mes, solo cuenta la diferencia
/// con lo que ya estaba guardado.
Future<String?> budgetAlertBeforeSaving(
  WidgetRef ref,
  AppLocalizations l10n, {
  required TransactionDraft draft,
  Transaction? previous,
}) async {
  final categoryId = draft.categoryId;
  if (draft.type != TransactionType.expense || categoryId == null) return null;

  try {
    final month = SummaryCalculator.monthStart(draft.date);
    final rules = await ref.read(budgetRulesProvider.future);
    final limit = BudgetCalculator.effectiveLimits(rules, month)[categoryId];
    if (limit == null) return null;

    final totals = await ref.read(monthlyTotalsProvider(month).future);
    final spent =
        SummaryCalculator.forMonth(
          totals,
          month,
        ).expenseCentsByCategory[categoryId] ??
        0;

    var added = _cents(double.parse(draft.amount));
    if (previous != null &&
        previous.type == TransactionType.expense &&
        previous.categoryId == categoryId &&
        SummaryCalculator.monthStart(previous.date) == month) {
      added -= _cents(previous.amount);
    }

    final alert = BudgetCalculator.alertForExpense(
      limitCents: limit,
      spentBeforeCents: spent,
      addedCents: added,
    );
    if (alert == null) return null;

    final name =
        ref.read(categoryNamesProvider)[categoryId] ?? l10n.budgetsThisCategory;
    return budgetAlertMessage(l10n, alert, name);
  } catch (_) {
    return null;
  }
}

int _cents(double amount) => (amount * 100).round();
