import 'package:flutter/material.dart';

import '../../../../core/format/money_format.dart';
import '../../domain/debt.dart';
import '../debt_ui.dart';

/// Una deuda en la lista: persona, lo que falta, el avance y cuándo vence.
class DebtTile extends StatelessWidget {
  const DebtTile({
    super.key,
    required this.debt,
    required this.today,
    required this.onTap,
  });

  final Debt debt;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = debt.statusOn(today);
    final statusColor =
        debtStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final statusIcon = debtStatusIcon(status);

    return Opacity(
      opacity: debt.isArchived ? 0.6 : 1,
      child: InkWell(
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
                      debt.counterparty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMoney(debt.remaining, currency: debt.currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (statusIcon != null) ...[
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      [
                        debtStatusText(debt, today),
                        if (debt.isArchived) 'Archivada',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    'de ${formatMoney(debt.amount, currency: debt.currency)}',
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
                  value: debt.progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
