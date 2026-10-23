import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../currency/presentation/currency_providers.dart';
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
///
/// El presupuesto está en la moneda base: un gasto de una cuenta en otra
/// moneda se pasa con la tasa de hoy, y si no hay tasa no se avisa.
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
    final converter = await ref.read(currencyConverterProvider.future);
    final accounts = await ref.read(accountsProvider.future);
    String? currencyOf(String accountId) => accounts
        .where((account) => account.id == accountId)
        .map((account) => account.currency)
        .firstOrNull;

    final spent =
        SummaryCalculator.forMonth(
          totals,
          month,
          converter,
        ).expenseCentsByCategory[categoryId] ??
        0;

    final draftCurrency = currencyOf(draft.accountId);
    if (draftCurrency == null) return null;
    var added = converter.toBaseCents(
      _cents(double.parse(draft.amount)),
      draftCurrency,
    );
    if (added == null) return null;

    if (previous != null &&
        previous.type == TransactionType.expense &&
        previous.categoryId == categoryId &&
        SummaryCalculator.monthStart(previous.date) == month) {
      final previousCurrency = currencyOf(previous.accountId);
      final before = previousCurrency == null
          ? null
          : converter.toBaseCents(_cents(previous.amount), previousCurrency);
      if (before == null) return null;
      added -= before;
    }

    final alert = BudgetCalculator.alertForExpense(
      limitCents: limit,
      spentBeforeCents: spent,
      addedCents: added,
    );
    if (alert == null) return null;

    final name =
        ref.read(categoryNamesProvider)[categoryId] ?? l10n.budgetsThisCategory;
    return budgetAlertMessage(l10n, alert, name, currency: converter.base);
  } catch (_) {
    return null;
  }
}

int _cents(double amount) => (amount * 100).round();
