import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/balance_history.dart';
import '../summary_colors.dart';

/// El dinero total al cierre de cada mes, en una línea.
///
/// Una sola serie: no necesita leyenda (el título dice qué es), el último valor
/// y el cambio van arriba en texto, y hay una vista en tabla con las mismas
/// cifras.
class BalanceHistoryCard extends StatefulWidget {
  const BalanceHistoryCard({
    super.key,
    required this.points,
    required this.selectedMonth,
    required this.currency,
  });

  final List<BalancePoint> points;

  /// La moneda de los montos (la base del usuario).
  final String currency;

  /// El mes que se está mirando: su etiqueta va en negrita.
  final DateTime selectedMonth;

  @override
  State<BalanceHistoryCard> createState() => _BalanceHistoryCardState();
}

class _BalanceHistoryCardState extends State<BalanceHistoryCard> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final colors = SummaryColors.of(context);
    final points = widget.points;
    final first = points.first.cents;
    final last = points.last.cents;
    final delta = last - first;

    final axis = LineAxis.forValues(
      points.map((p) => p.cents).reduce((a, b) => a < b ? a : b) / 100,
      points.map((p) => p.cents).reduce((a, b) => a > b ? a : b) / 100,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: colors.axisLabel);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dashboardTotalMoney, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              l10n.summaryHistorySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              formats.money(last / 100, currency: widget.currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            _DeltaLine(
              delta: delta,
              months: points.length,
              currency: widget.currency,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: l10n.summaryHistorySemantics(points.length),
              excludeSemantics: true,
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: axis.min,
                    maxY: axis.max,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: axis.step,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: colors.grid, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      border: Border(bottom: BorderSide(color: colors.baseline)),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 64,
                          interval: axis.step,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              formats.compactMoney(value, currency: widget.currency),
                              style: labelStyle,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final month = points[index].month;
                            final selected = month == widget.selectedMonth;
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                formats.monthShort(month),
                                style: labelStyle?.copyWith(
                                  fontWeight: selected ? FontWeight.bold : null,
                                  color: selected ? theme.colorScheme.onSurface : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            LineTooltipItem(
                              '${formats.month(points[spot.x.toInt()].month)}\n'
                              '${formats.money(spot.y, currency: widget.currency)}',
                              TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].cents / 100),
                        ],
                        color: colors.balance,
                        barWidth: 2.5,
                        isCurved: false,
                        dotData: FlDotData(
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: colors.balance,
                                strokeWidth: 2,
                                strokeColor: theme.colorScheme.surface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showTable = !_showTable),
                icon: Icon(_showTable ? Icons.expand_less : Icons.table_rows),
                label: Text(
                  _showTable
                      ? l10n.summaryHistoryHideTable
                      : l10n.summaryHistoryShowTable,
                ),
              ),
            ),
            if (_showTable)
              _BalanceTable(points: points, currency: widget.currency),
          ],
        ),
      ),
    );
  }
}

/// "▲ $320.000 más que hace 5 meses": cuánto cambió el dinero en la ventana.
class _DeltaLine extends StatelessWidget {
  const _DeltaLine({
    required this.delta,
    required this.months,
    required this.currency,
  });

  final int delta;
  final int months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final span = months - 1;
    final since = span == 1
        ? l10n.summarySincePrevious
        : l10n.summarySinceMonths(span);

    final (IconData icon, Color? color, String text) = delta > 0
        ? (
            Icons.arrow_upward,
            theme.colorScheme.primary,
            l10n.summaryDeltaUp(
              formats.money(delta / 100, currency: currency),
              since,
            ),
          )
        : delta < 0
        ? (
            Icons.arrow_downward,
            theme.colorScheme.error,
            l10n.summaryDeltaDown(
              formats.money(-delta / 100, currency: currency),
              since,
            ),
          )
        : (Icons.remove, null, l10n.summaryDeltaSame(since));

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _BalanceTable extends StatelessWidget {
  const _BalanceTable({required this.points, required this.currency});

  final List<BalancePoint> points;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final header = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    TableRow row(Widget month, Widget total) => TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: month),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: total),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Table(
        children: [
          row(
            Text(l10n.summaryHistoryTableClosing, style: header),
            Text(
              l10n.dashboardTotalMoney,
              textAlign: TextAlign.end,
              style: header,
            ),
          ),
          for (final point in points)
            row(
              Text(
                formats.month(point.month),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                formats.money(point.cents / 100, currency: currency),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
