import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formats.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../domain/balance_history.dart';
import '../domain/month_summary.dart';
import 'summary_colors.dart';
import 'summary_comparison.dart';
import 'summary_error_message.dart';
import 'summary_providers.dart';
import 'widgets/balance_history_card.dart';
import 'widgets/category_ranking.dart';
import 'widgets/month_navigator.dart';
import 'widgets/monthly_trend_chart.dart';
import 'widgets/pace_card.dart';
import 'widgets/stat_tile.dart';

/// Lo que se dibuja: el resumen del mes y la tendencia de los últimos meses.
class _SummaryView {
  const _SummaryView({
    required this.summary,
    required this.previous,
    required this.trend,
    required this.hasAnyData,
  });

  final MonthSummary summary;

  /// El mes anterior, para comparar.
  final MonthSummary previous;
  final List<MonthPoint> trend;

  /// Falso si no hay un solo movimiento en todo el período consultado.
  final bool hasAnyData;
}

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late DateTime _month = _currentMonth;
  TransactionType _kind = TransactionType.expense;

  /// Lo último que se dibujó: al cambiar de mes se mantiene a media opacidad
  /// mientras llega el nuevo, en vez de saltar a un indicador de carga.
  _SummaryView? _shown;

  DateTime get _currentMonth => SummaryCalculator.monthStart(DateTime.now());

  void _move(int months) => setState(
    () => _month = SummaryCalculator.addMonths(_month, months),
  );

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(monthlyTotalsProvider(_month));

    if (totals.hasValue && !totals.isLoading) {
      final rows = totals.requireValue;
      _shown = _SummaryView(
        summary: SummaryCalculator.forMonth(rows, _month),
        previous: SummaryCalculator.forMonth(
          rows,
          SummaryCalculator.addMonths(_month, -1),
        ),
        trend: SummaryCalculator.trend(rows, _month, months: trendMonths),
        hasAnyData: rows.isNotEmpty,
      );
    }
    final failed = totals.hasError && !totals.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.summaryTitle)),
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
            child: totals.isLoading && _shown != null
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(child: _body(totals, failed)),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<Object?> totals, bool failed) {
    final l10n = context.l10n;
    if (failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        text: summaryErrorMessage(l10n, totals.error!),
        actionLabel: l10n.commonRetry,
        onAction: () => ref.invalidate(monthlyTotalsProvider(_month)),
      );
    }

    final view = _shown;
    if (view == null) return const Center(child: CircularProgressIndicator());

    if (!view.hasAnyData) {
      return StateMessage(
        icon: Icons.insights_outlined,
        text: l10n.summaryNoData,
        actionLabel: l10n.transactionsRecordOne,
        onAction: () => showTransactionForm(context),
      );
    }

    return Opacity(
      opacity: totals.isLoading ? 0.5 : 1,
      child: _SummaryBody(
        view: view,
        month: _month,
        kind: _kind,
        onKindChanged: (kind) => setState(() => _kind = kind),
      ),
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.view,
    required this.month,
    required this.kind,
    required this.onKindChanged,
  });

  final _SummaryView view;
  final DateTime month;
  final TransactionType kind;
  final ValueChanged<TransactionType> onKindChanged;

  /// La evolución del dinero total, con su separación; nada si no hay cuentas
  /// activas. Si falla la carga, lo dice (con la opción de reintentar).
  Widget _balanceHistory(BuildContext context, WidgetRef ref, DateTime month) {
    final accounts = ref.watch(accountsProvider);
    final flows = ref.watch(accountFlowsProvider);

    if (flows.hasError && !flows.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(context.l10n.summaryHistoryError),
            trailing: TextButton(
              onPressed: () => ref.invalidate(accountFlowsProvider),
              child: Text(context.l10n.commonRetry),
            ),
          ),
        ),
      );
    }

    final loaded = accounts.value;
    final flowRows = flows.value;
    if (loaded == null ||
        flowRows == null ||
        loaded.every((account) => account.isArchived)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BalanceHistoryCard(
        points: BalanceHistory.compute(
          accounts: loaded,
          flows: flowRows,
          end: month,
          months: trendMonths,
        ),
        selectedMonth: month,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final colors = SummaryColors.of(context);
    final names = ref.watch(categoryNamesProvider);
    final summary = view.summary;

    final balance = summary.balanceCents;
    final (icon, iconColor, caption) = balance > 0
        ? (
            Icons.arrow_upward,
            theme.colorScheme.primary,
            l10n.summaryBalanceUp,
          )
        : balance < 0
        ? (
            Icons.arrow_downward,
            theme.colorScheme.error,
            l10n.summaryBalanceDown,
          )
        : (Icons.remove, null, l10n.summaryBalanceEven);

    final isExpense = kind == TransactionType.expense;
    final shares = isExpense
        ? summary.expenseByCategory
        : summary.incomeByCategory;

    // Cada cifra se compara con el mes anterior, si tuvo movimientos.
    final previous = view.previous;
    final previousName = formats.monthName(previous.month);
    ComparisonCaption? compare(int current, int before, TransactionType kind) =>
        compareWithPrevious(
          l10n,
          current: current,
          previous: before,
          previousHasData: !previous.isEmpty,
          previousMonthName: previousName,
          noneKind: kind,
        );
    final incomeComparison = compare(
      summary.incomeCents,
      previous.incomeCents,
      TransactionType.income,
    );
    final expenseComparison = compare(
      summary.expenseCents,
      previous.expenseCents,
      TransactionType.expense,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        StatTile(
          hero: true,
          label: l10n.summaryBalanceOfMonth,
          value: formats.money(balance / 100),
          caption: caption,
          captionIcon: icon,
          captionIconColor: iconColor,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                label: l10n.commonIncomes,
                value: formats.money(summary.incomeCents / 100),
                marker: colors.income,
                caption: incomeComparison?.text,
                captionIcon: incomeComparison?.icon,
                captionIconColor: incomeComparison?.color(
                  theme.colorScheme,
                  upIsGood: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: l10n.commonExpenses,
                value: formats.money(summary.expenseCents / 100),
                marker: colors.expense,
                caption: expenseComparison?.text,
                captionIcon: expenseComparison?.icon,
                captionIconColor: expenseComparison?.color(
                  theme.colorScheme,
                  upIsGood: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PaceCard(summary: summary, previous: previous, today: DateTime.now()),
        const SizedBox(height: 16),
        MonthlyTrendChart(points: view.trend, selectedMonth: month),
        const SizedBox(height: 16),
        _balanceHistory(context, ref, month),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpense
                      ? l10n.summaryWhereMoneyGoes
                      : l10n.summaryWhereMoneyComes,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text(l10n.commonExpenses),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text(l10n.commonIncomes),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (selection) =>
                      onKindChanged(selection.first),
                ),
                const SizedBox(height: 12),
                if (shares.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      isExpense
                          ? l10n.summaryNoExpensesMonth
                          : l10n.summaryNoIncomeMonth,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  CategoryRanking(
                    shares: shares,
                    names: names,
                    color: isExpense ? colors.expense : colors.income,
                    mutedColor: colors.axisLabel,
                    previousCents: isExpense
                        ? previous.expenseCentsByCategory
                        : previous.incomeCentsByCategory,
                    previousHasData: !previous.isEmpty,
                    previousMonthName: previousName,
                    upIsGood: !isExpense,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(l10n.budgetsTitle),
            subtitle: Text(l10n.summaryBudgetsLink),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.budgets),
          ),
        ),
      ],
    );
  }
}
