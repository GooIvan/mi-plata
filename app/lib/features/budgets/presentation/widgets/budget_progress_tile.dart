import 'package:flutter/material.dart';

import '../../../../core/format/money_format.dart';
import '../../domain/budget_calculator.dart';
import '../budget_ui.dart';

/// Una categoría con presupuesto: lo gastado, el límite, una barra de avance y
/// una frase que dice cómo va.
class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    super.key,
    required this.name,
    required this.progress,
    this.onTap,
  });

  final String name;
  final BudgetProgress progress;

  /// Null cuando el mes no se puede editar (meses pasados).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = progress.status;
    final color = budgetStatusColor(status);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMoney(progress.spentCents / 100),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' de ${formatMoney(progress.limitCents / 100)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.fraction.clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(budgetStatusIcon(status), size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    budgetStatusText(status, progress.remainingCents),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${(progress.fraction * 100).round()} %',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
