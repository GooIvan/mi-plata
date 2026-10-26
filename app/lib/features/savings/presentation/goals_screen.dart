import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../domain/goal_progress.dart';
import 'goal_detail_screen.dart';
import 'goal_error_message.dart';
import 'goals_providers.dart';
import 'widgets/goal_form_sheet.dart';
import 'widgets/goal_tile.dart';

/// Las metas de ahorro: las activas, de la que vence antes a la que no tiene
/// fecha, y (si se piden) las archivadas.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalProgressProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.goalsTitle),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? l10n.commonHideArchived
                : l10n.commonShowArchived,
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: goalErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(savingsGoalsProvider),
        ),
        data: _buildList,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Las pestañas viven a la vez: sin etiqueta de héroe compartida.
        heroTag: null,
        onPressed: () => showGoalForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.goalsNew),
      ),
    );
  }

  Widget _buildList(List<GoalProgress> all) {
    final l10n = context.l10n;
    if (all.isEmpty) {
      return StateMessage(
        icon: Icons.flag_outlined,
        text: l10n.goalsEmpty,
        actionLabel: l10n.goalsCreateButton,
        onAction: () => showGoalForm(context),
      );
    }

    final today = DateTime.now();
    int byDeadline(GoalProgress a, GoalProgress b) => compareGoals(a, b, today);
    final active = all.where((p) => !p.goal.isArchived).toList()
      ..sort(byDeadline);
    final archived = all.where((p) => p.goal.isArchived).toList()
      ..sort(byDeadline);
    final visible = [...active, if (_showArchived) ...archived];

    if (visible.isEmpty) {
      return StateMessage(
        icon: Icons.inventory_2_outlined,
        text: l10n.goalsAllArchived,
        actionLabel: l10n.commonShowArchived,
        onAction: () => setState(() => _showArchived = true),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final progress = visible[index];
        return GoalTile(
          progress: progress,
          today: today,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GoalDetailScreen(goalId: progress.goal.id),
            ),
          ),
        );
      },
    );
  }
}
