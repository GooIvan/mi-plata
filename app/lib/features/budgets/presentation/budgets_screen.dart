import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/presentation/summary_providers.dart';
import '../../summary/presentation/widgets/month_navigator.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/budget_calculator.dart';
import 'budget_error_message.dart';
import 'budget_providers_overview.dart';
import 'budgets_providers.dart';
import 'budget_ui.dart';
import 'widgets/budget_form_sheet.dart';
import 'widgets/budget_progress_tile.dart';

/// Los presupuestos del mes: cuánto se lleva gastado de lo que se quería gastar.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late DateTime _month = _currentMonth;

  /// Lo último que se dibujó: al cambiar de mes se mantiene atenuado mientras
  /// llega el nuevo.
  BudgetOverview? _shown;

  DateTime get _currentMonth => SummaryCalculator.monthStart(DateTime.now());

  /// Solo el mes actual se edita: un presupuesto rige "desde este mes", así que
  /// cambiarlo viendo un mes pasado reescribiría la historia.
  bool get _canEdit => _month == _currentMonth;

  void _move(int months) =>
      setState(() => _month = SummaryCalculator.addMonths(_month, months));

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(budgetOverviewProvider(_month));

    if (overview.hasValue && !overview.isLoading) {
      _shown = overview.requireValue;
    }
    final failed = overview.hasError && !overview.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.budgetsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: MonthNavigator(
              month: _month,
              canGoNext: _month.isBefore(_currentMonth),
              onPrevious: () => _move(-1),
              onNext: () => _move(1),
            ),
          ),
          SizedBox(
            height: 3,
            child: overview.isLoading && _shown != null
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(child: _body(overview, failed)),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => showBudgetForm(
                context,
                month: _month,
                budgetedIds: {
                  for (final budget
                      in _shown?.budgeted ?? const <BudgetProgress>[])
                    budget.categoryId,
                },
              ),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.budgetsNew),
            )
          : null,
    );
  }

  Widget _body(AsyncValue<BudgetOverview> overview, bool failed) {
    final l10n = context.l10n;
    if (failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        text: budgetErrorMessage(l10n, overview.error!),
        actionLabel: l10n.commonRetry,
        onAction: () {
          // El presupuesto junta dos consultas: se repiten las dos, porque la
          // que falló se queda con su error mientras alguien la esté mirando.
          ref.invalidate(budgetRulesProvider);
          ref.invalidate(monthlyTotalsProvider(_month));
          ref.invalidate(budgetOverviewProvider(_month));
        },
      );
    }

    final data = _shown;
    if (data == null) return const Center(child: CircularProgressIndicator());

    if (!data.hasBudgets && data.unbudgeted.isEmpty) {
      return StateMessage(
        icon: Icons.savings_outlined,
        text: _canEdit ? l10n.budgetsEmptyEditable : l10n.budgetsEmptyPast,
        actionLabel: _canEdit
            ? l10n.budgetsDefine
            : l10n.budgetsGoToCurrentMonth,
        onAction: _canEdit
            ? () => showBudgetForm(context, month: _month)
            : () => setState(() => _month = _currentMonth),
      );
    }

    return Opacity(
      opacity: ref.watch(budgetOverviewProvider(_month)).isLoading ? 0.5 : 1,
      child: _Content(overview: data, month: _month, canEdit: _canEdit),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.overview,
    required this.month,
    required this.canEdit,
  });

  final BudgetOverview overview;
  final DateTime month;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final names = ref.watch(categoryNamesProvider);
    final budgetedIds = {for (final b in overview.budgeted) b.categoryId};

    String nameOf(String? id) =>
        id == null ? l10n.commonNoCategory : names[id] ?? l10n.commonCategory;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (overview.hasBudgets) _OverviewCard(overview: overview),
        if (overview.hasBudgets) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              l10n.budgetsWithBudget,
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final progress in overview.budgeted) ...[
            BudgetProgressTile(
              name: nameOf(progress.categoryId),
              progress: progress,
              onTap: canEdit
                  ? () => showBudgetForm(
                      context,
                      month: month,
                      categoryId: progress.categoryId,
                      currentCents: progress.limitCents,
                      budgetedIds: budgetedIds,
                    )
                  : null,
            ),
            const Divider(height: 1),
          ],
        ],
        if (overview.unbudgeted.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              l10n.budgetsWithoutBudget,
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final spending in overview.unbudgeted)
            ListTile(
              title: Text(nameOf(spending.categoryId)),
              subtitle: canEdit && spending.categoryId != null
                  ? Text(l10n.budgetsTapToDefine)
                  : null,
              trailing: Text(
                context.formats.money(spending.spentCents / 100),
                style: theme.textTheme.titleMedium,
              ),
              // "Sin categoría" no tiene a quién ponerle un presupuesto.
              onTap: canEdit && spending.categoryId != null
                  ? () => showBudgetForm(
                      context,
                      month: month,
                      categoryId: spending.categoryId,
                      budgetedIds: budgetedIds,
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}

/// Todo lo presupuestado junto: cuánto se lleva gastado y cuánto queda.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final BudgetOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final status = overview.status;
    final color = budgetStatusColor(status);
    final attention = budgetAttentionText(l10n, overview);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.budgetsTotalTitle, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                formats.money(overview.totalSpentCents / 100),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                l10n.budgetsTotalOf(formats.money(overview.totalLimitCents / 100)),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: overview.fraction.clamp(0.0, 1.0),
                  minHeight: 10,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(budgetStatusIcon(status), size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      budgetStatusText(
                        l10n,
                        status,
                        overview.totalRemainingCents,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(l10n.commonPercent((overview.fraction * 100).round())),
                ],
              ),
              if (attention != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 2),
                  child: Text(
                    attention,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
