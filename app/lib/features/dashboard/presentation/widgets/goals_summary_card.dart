import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../savings/domain/goal_progress.dart';
import '../../../savings/presentation/goal_detail_screen.dart';
import '../../../savings/presentation/goal_error_message.dart';
import '../../../savings/presentation/widgets/goal_tile.dart';

/// Las metas de ahorro activas que vencen primero, con su avance. Si no hay
/// ninguna, invita a crear una. Al tocar una meta abre su detalle.
class GoalsSummaryCard extends StatelessWidget {
  const GoalsSummaryCard({
    super.key,
    required this.goals,
    required this.onOpenAll,
  });

  final AsyncValue<List<GoalProgress>> goals;
  final VoidCallback onOpenAll;

  /// Cuántas metas se muestran como máximo; el resto, en la lista completa.
  static const maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = DateTime.now();

    Widget text(String message) => InkWell(
      onTap: onOpenAll,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: goals.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => text(goalErrorMessage(l10n, error)),
        data: (all) {
          final active = [
            for (final progress in all)
              if (!progress.goal.isArchived) progress,
          ]..sort((a, b) => compareGoals(a, b, today));
          if (active.isEmpty) return text(l10n.goalsDashboardEmpty);

          final shown = active.take(maxShown).toList();
          return Column(
            children: [
              for (final progress in shown) ...[
                GoalTile(
                  progress: progress,
                  today: today,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GoalDetailScreen(goalId: progress.goal.id),
                    ),
                  ),
                ),
                if (progress != shown.last) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}
