import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../transactions/domain/transaction_type.dart';
import '../../domain/month_summary.dart';
import '../summary_comparison.dart';

/// A qué ritmo se gasta: el promedio de cada día y, mientras el mes sigue en
/// curso, cuánto sumaría a fin de mes si el ritmo se mantiene.
class PaceCard extends StatelessWidget {
  const PaceCard({
    super.key,
    required this.summary,
    required this.previous,
    required this.today,
  });

  final MonthSummary summary;

  /// El mes anterior, para comparar la proyección.
  final MonthSummary previous;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final pace = SummaryCalculator.pace(summary, today);
    final isCurrentMonth = summary.month == SummaryCalculator.monthStart(today);
    final projected = pace.projectedCents;

    final comparison = projected == null
        ? null
        : compareWithPrevious(
            l10n,
            current: projected,
            previous: previous.expenseCents,
            previousHasData: !previous.isEmpty,
            previousMonthName: formats.monthName(previous.month),
            noneKind: TransactionType.expense,
          );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.summaryPaceTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            // Son estimaciones: en pesos enteros, sin centavos que aparentan
            // una precisión que no tienen.
            _Row(
              label: l10n.summaryDailyAverage,
              value: formats.money(
                (pace.dailyAverageCents / 100).roundToDouble(),
              ),
            ),
            if (projected != null) ...[
              const SizedBox(height: 8),
              _Row(
                label: l10n.summaryProjectedClose,
                value: formats.money((projected / 100).roundToDouble()),
              ),
            ],
            if (comparison != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    comparison.icon,
                    size: 16,
                    color: comparison.color(theme.colorScheme, upIsGood: false),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.summaryProjection(comparison.text),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              isCurrentMonth
                  ? l10n.summaryCalculatedPartial(
                      pace.daysCounted,
                      pace.daysInMonth,
                    )
                  : l10n.summaryCalculatedFull(pace.daysInMonth),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
