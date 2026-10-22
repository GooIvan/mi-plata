import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/state_message.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/month_summary.dart';
import 'summary_colors.dart';
import 'summary_comparison.dart';
import 'summary_error_message.dart';
import 'summary_providers.dart';
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
      appBar: AppBar(title: const Text('Resumen mensual')),
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
    if (failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        text: summaryErrorMessage(totals.error!),
        actionLabel: 'Reintentar',
        onAction: () => ref.invalidate(monthlyTotalsProvider(_month)),
      );
    }

    final view = _shown;
    if (view == null) return const Center(child: CircularProgressIndicator());

    if (!view.hasAnyData) {
      return StateMessage(
        icon: Icons.insights_outlined,
        text: 'Aún no hay movimientos para resumir.\n'
            'Registra ingresos y gastos para ver tu resumen.',
        actionLabel: 'Registrar movimiento',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = SummaryColors.of(context);
    final names = ref.watch(categoryNamesProvider);
    final summary = view.summary;

    final balance = summary.balanceCents;
    final (icon, iconColor, caption) = balance > 0
        ? (
            Icons.arrow_upward,
            theme.colorScheme.primary,
            'Ingresaste más de lo que gastaste',
          )
        : balance < 0
        ? (
            Icons.arrow_downward,
            theme.colorScheme.error,
            'Gastaste más de lo que ingresaste',
          )
        : (Icons.remove, null, 'Ingresos y gastos iguales');

    final isExpense = kind == TransactionType.expense;
    final shares = isExpense
        ? summary.expenseByCategory
        : summary.incomeByCategory;

    // Cada cifra se compara con el mes anterior, si tuvo movimientos.
    final previous = view.previous;
    final previousName = formatMonthName(previous.month);
    ComparisonCaption? compare(int current, int before, String noun) =>
        compareWithPrevious(
          current: current,
          previous: before,
          previousHasData: !previous.isEmpty,
          previousMonthName: previousName,
          noneNoun: noun,
        );
    final incomeComparison = compare(
      summary.incomeCents,
      previous.incomeCents,
      'ingresos',
    );
    final expenseComparison = compare(
      summary.expenseCents,
      previous.expenseCents,
      'gastos',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        StatTile(
          hero: true,
          label: 'Balance del mes',
          value: formatMoney(balance / 100),
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
                label: 'Ingresos',
                value: formatMoney(summary.incomeCents / 100),
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
                label: 'Gastos',
                value: formatMoney(summary.expenseCents / 100),
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
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpense ? '¿En qué se va el dinero?' : '¿De dónde viene?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Gastos'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Ingresos'),
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
                          ? 'No hay gastos en este mes.'
                          : 'No hay ingresos en este mes.',
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
      ],
    );
  }
}
