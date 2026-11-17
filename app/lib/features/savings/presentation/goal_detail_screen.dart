import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../currency/presentation/currency_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/presentation/widgets/transaction_detail_sheet.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/goal_movement.dart';
import '../domain/goal_progress.dart';
import 'goal_error_message.dart';
import 'goal_ui.dart';
import 'goals_providers.dart';
import 'widgets/goal_form_sheet.dart';

/// El detalle de una meta: cuánto se lleva, cómo va, cuánto ahorrar para llegar
/// a tiempo y los movimientos de su cuenta.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress, {
    required bool archived,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(savingsGoalsProvider.notifier)
          .setArchived(progress.goal.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(goalErrorMessage(l10n, error))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived ? l10n.goalsArchivedMessage : l10n.goalsRestoredMessage,
        ),
      ),
    );
  }

  /// Ahorrar es pasar plata a la cuenta de la meta; sacar, pasarla a otra. Si
  /// solo hay otra cuenta, ya viene elegida.
  void _move(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress, {
    required bool saving,
  }) {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final others = [
      for (final account in accounts)
        if (!account.isArchived && account.id != progress.goal.accountId)
          account,
    ];
    final other = others.length == 1 ? others.single.id : null;

    showTransactionForm(
      context,
      initialType: TransactionType.transfer,
      initialAccountId: saving ? other : progress.goal.accountId,
      initialDestinationId: saving ? progress.goal.accountId : other,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(goalProgressProvider);
    final progress = goals.value
        ?.where((progress) => progress.goal.id == goalId)
        .firstOrNull;

    if (progress == null) {
      return Scaffold(
        appBar: AppBar(),
        body: goals.hasError && !goals.isLoading
            ? StateMessage(
                icon: Icons.cloud_off_outlined,
                text: goalErrorMessage(l10n, goals.error!),
                actionLabel: l10n.commonRetry,
                onAction: () => ref.invalidate(savingsGoalsProvider),
              )
            : goals.isLoading
            ? const Center(child: CircularProgressIndicator())
            : StateMessage(
                icon: Icons.search_off,
                text: l10n.goalsGone,
                actionLabel: l10n.commonBack,
                onAction: () => Navigator.of(context).pop(),
              ),
      );
    }

    final theme = Theme.of(context);
    final formats = context.formats;
    final today = DateTime.now();
    final goal = progress.goal;
    final status = progress.statusOn(today);
    final statusColor = goalStatusColor(status, theme.colorScheme);
    final suggestion = goal.isArchived
        ? null
        : goalSuggestion(l10n, progress, today);
    final base = ref.watch(currencyConverterProvider).value?.base;
    final accountName = base != null && progress.currency != base
        ? '${progress.accountName} · ${progress.currency}'
        : progress.accountName;
    final canMove = !goal.isArchived && !progress.accountArchived;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            tooltip: l10n.goalsEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showGoalForm(context, goal: goal),
          ),
          PopupMenuButton<bool>(
            tooltip: l10n.commonOptions,
            onSelected: (archive) =>
                _setArchived(context, ref, progress, archived: archive),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: !goal.isArchived,
                child: Text(
                  goal.isArchived ? l10n.goalsRestore : l10n.goalsArchive,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (goal.targetDate != null)
                    Text(
                      l10n.goalsDeadlineOn(formats.fullDate(goal.targetDate!)),
                      style: theme.textTheme.labelLarge,
                    ),
                  if (goal.targetDate != null) const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formats.money(
                        progress.savedCents / 100,
                        currency: progress.currency,
                      ),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    l10n.goalsSavedOf(
                      l10n.commonPercent(progress.percent),
                      formats.money(
                        progress.targetCents / 100,
                        currency: progress.currency,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 12,
                      color: goal.isArchived
                          ? theme.colorScheme.outline
                          : statusColor,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          goal.isArchived
                              ? Icons.inventory_2_outlined
                              : goalStatusIcon(status),
                          size: 18,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          goal.isArchived
                              ? l10n.goalsArchivedLabel
                              : goalStatusText(l10n, progress, today),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (suggestion != null) ...[
                    const SizedBox(height: 4),
                    Text(suggestion, style: theme.textTheme.bodySmall),
                  ],
                  if (progress.isReached && !goal.isArchived) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.goalsReachedHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    l10n.goalsAccountRow(accountName),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (progress.accountArchived)
                    Text(
                      l10n.goalsAccountArchivedNote(progress.accountName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!goal.isArchived) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canMove
                        ? () => _move(context, ref, progress, saving: true)
                        : null,
                    icon: const Icon(Icons.savings_outlined),
                    label: Text(l10n.goalsSave),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canMove
                        ? () => _move(context, ref, progress, saving: false)
                        : null,
                    icon: const Icon(Icons.output_outlined),
                    label: Text(l10n.goalsWithdraw),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.goalsHistoryTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _History(accountId: goal.accountId, currency: progress.currency),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.accountId, required this.currency});

  final String accountId;
  final String currency;

  /// Qué dice un movimiento de la cuenta de la meta: su descripción o, si no
  /// tiene, de dónde viene o a dónde va.
  String _title(
    AppLocalizations l10n,
    Transaction t,
    Map<String, String> names,
  ) {
    final description = t.description;
    if (description != null && description.isNotEmpty) return description;
    if (t.type == TransactionType.transfer) {
      return t.accountId == accountId
          ? l10n.goalsMovementTo(
              names[t.destinationAccountId] ?? l10n.commonAccount,
            )
          : l10n.goalsMovementFrom(names[t.accountId] ?? l10n.commonAccount);
    }
    return t.type == TransactionType.income
        ? l10n.transactionTypeIncome
        : l10n.transactionTypeExpense;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final history = ref.watch(goalHistoryProvider(accountId));
    final names = ref.watch(accountNamesProvider);

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(goalErrorMessage(l10n, error)),
          trailing: TextButton(
            onPressed: () => ref.invalidate(goalHistoryProvider(accountId)),
            child: Text(l10n.commonRetry),
          ),
        ),
      ),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.goalsHistoryEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final transaction in list)
                    _MovementTile(
                      title: _title(l10n, transaction, names),
                      date: formats.fullDate(transaction.date),
                      deltaCents: accountDeltaCents(transaction, accountId),
                      currency: currency,
                      onTap: () => showTransactionDetail(context, transaction),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.title,
    required this.date,
    required this.deltaCents,
    required this.currency,
    required this.onTap,
  });

  final String title;
  final String date;
  final int deltaCents;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = context.formats;
    final entered = deltaCents >= 0;
    // Entra plata: verde; sale: el color de error del tema.
    final color = entered ? const Color(0xFF0CA30C) : theme.colorScheme.error;

    return ListTile(
      onTap: onTap,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(date),
      trailing: Text(
        '${entered ? '+' : '−'}${formats.money(deltaCents.abs() / 100, currency: currency)}',
        style: theme.textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}
