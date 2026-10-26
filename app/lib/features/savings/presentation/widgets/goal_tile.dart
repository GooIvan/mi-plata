import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/goal_progress.dart';
import '../goal_ui.dart';

/// Una meta: su nombre, lo ahorrado frente a lo que se quiere, una barra de
/// avance y una frase que dice cómo va.
class GoalTile extends StatelessWidget {
  const GoalTile({
    super.key,
    required this.progress,
    required this.today,
    this.onTap,
  });

  final GoalProgress progress;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final archived = progress.goal.isArchived;
    final status = progress.statusOn(today);
    final color = archived
        ? theme.colorScheme.outline
        : goalStatusColor(status, theme.colorScheme);

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
                    progress.goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.commonPercent(progress.percent),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 8,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.goalsSavedOf(
                formats.money(
                  progress.savedCents / 100,
                  currency: progress.currency,
                ),
                formats.money(
                  progress.targetCents / 100,
                  currency: progress.currency,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    archived
                        ? Icons.inventory_2_outlined
                        : goalStatusIcon(status),
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    archived
                        ? l10n.goalsArchivedLabel
                        : goalStatusText(l10n, progress, today),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
