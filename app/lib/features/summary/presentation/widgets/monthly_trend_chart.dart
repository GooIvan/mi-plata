import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/month_summary.dart';
import '../summary_colors.dart';

/// Ingresos y gastos de los últimos meses, en barras agrupadas.
///
/// Dos series que se distinguen por identidad: leyenda siempre visible, ejes
/// y cuadrícula apenas marcados, y una vista en tabla con las mismas cifras
/// (el gráfico nunca es la única forma de leer un valor).
class MonthlyTrendChart extends StatefulWidget {
  const MonthlyTrendChart({
    super.key,
    required this.points,
    required this.selectedMonth,
  });

  final List<MonthPoint> points;

  /// El mes que se está mirando: su etiqueta va en negrita.
  final DateTime selectedMonth;

  /// Un eje con cifras redondas y pocas marcas: el paso es 1, 2, 2,5 o 5 por
  /// una potencia de diez, el más chico con el que el valor más alto cabe en
  /// cinco tramos o menos. Así las barras aprovechan la altura del gráfico.
  @visibleForTesting
  static ({double step, double max}) axisFor(double highest) {
    if (highest <= 0) return (step: 1000, max: 4000);

    var power = math.pow(10, (math.log(highest) / math.ln10).floor() - 1);
    while (true) {
      for (final factor in const [1.0, 2.0, 2.5, 5.0]) {
        final step = factor * power;
        final intervals = (highest / step - 1e-9).ceil();
        if (intervals <= 5) return (step: step, max: step * intervals);
      }
      power *= 10;
    }
  }

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final colors = SummaryColors.of(context);
    final points = widget.points;

    final highest = points
        .map((p) => math.max(p.incomeCents, p.expenseCents))
        .fold(0, math.max);
    final axis = MonthlyTrendChart.axisFor(highest / 100);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.axisLabel,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.summaryTrendTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              l10n.summaryLastMonths(points.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendItem(color: colors.income, label: l10n.commonIncomes),
                const SizedBox(width: 16),
                _LegendItem(color: colors.expense, label: l10n.commonExpenses),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: l10n.summaryTrendSemantics(points.length),
              excludeSemantics: true,
              child: SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: axis.max,
                    minY: 0,
                    alignment: BarChartAlignment.spaceAround,
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
                          reservedSize: 52,
                          interval: axis.step,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              formats.compactMoney(value),
                              style: labelStyle,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final month = points[value.toInt()].month;
                            final selected = month == widget.selectedMonth;
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                formats.monthShort(month),
                                style: labelStyle?.copyWith(
                                  fontWeight: selected ? FontWeight.bold : null,
                                  color: selected
                                      ? theme.colorScheme.onSurface
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              l10n.summaryTrendTooltip(
                                formats.month(points[groupIndex].month),
                                rodIndex == 0
                                    ? l10n.commonIncomes
                                    : l10n.commonExpenses,
                                formats.money(rod.toY),
                              ),
                              TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12,
                              ),
                            ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            _rod(points[i].incomeCents / 100, colors.income),
                            _rod(points[i].expenseCents / 100, colors.expense),
                          ],
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
                  _showTable ? l10n.summaryHideTable : l10n.summaryShowTable,
                ),
              ),
            ),
            if (_showTable) _TrendTable(points: points),
          ],
        ),
      ),
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points});

  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final header = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    TableRow row(List<Widget> cells) => TableRow(
      children: [
        for (final cell in cells)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: cell),
      ],
    );

    Widget amount(int cents) => Text(
      formats.money(cents / 100),
      textAlign: TextAlign.end,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.1)},
        children: [
          row([
            Text(l10n.summaryTableMonth, style: header),
            Text(l10n.commonIncomes, textAlign: TextAlign.end, style: header),
            Text(l10n.commonExpenses, textAlign: TextAlign.end, style: header),
          ]),
          for (final point in points)
            row([
              Text(
                formats.month(point.month),
                style: theme.textTheme.bodySmall,
              ),
              amount(point.incomeCents),
              amount(point.expenseCents),
            ]),
        ],
      ),
    );
  }
}
