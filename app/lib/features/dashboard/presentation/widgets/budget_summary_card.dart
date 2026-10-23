import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../budgets/domain/budget_calculator.dart';
import '../../../budgets/presentation/budget_ui.dart';

/// Cómo van los presupuestos del mes, de un vistazo. Al tocarla abre el detalle.
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.overview,
    required this.onTap,
  });

  final BudgetOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final status = overview.status;
    final color = budgetStatusColor(status);
    final attention = budgetAttentionText(l10n, overview);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: formats.money(overview.totalSpentCents / 100),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  ' ${l10n.budgetsOfLimit(formats.money(overview.totalLimitCents / 100))}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: overview.fraction.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(budgetStatusIcon(status), size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      budgetStatusText(
                        l10n,
                        status,
                        overview.totalRemainingCents,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (attention != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    attention,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
