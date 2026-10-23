import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../recurring/domain/recurring_payment.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../recurring/presentation/recurring_ui.dart';
import '../../recurring/presentation/widgets/confirm_payment_sheet.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/debt.dart';
import '../domain/debt_direction.dart';
import '../domain/debt_payment.dart';
import 'debt_error_message.dart';
import 'debt_form_screen.dart';
import 'debt_ui.dart';
import 'debts_providers.dart';
import 'widgets/payment_sheet.dart';

enum _DebtMenuAction { toggleArchived }

/// El detalle de una deuda: lo pagado y pendiente, y sus abonos.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    Debt debt, {
    required bool archived,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref
          .read(debtsProvider.notifier)
          .setArchived(debt.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(debtErrorMessage(l10n, error))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived ? l10n.debtsArchivedMessage : l10n.debtsRestoredMessage,
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => ref
              .read(debtsProvider.notifier)
              .setArchived(debt.id, isArchived: !archived),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    final l10n = context.l10n;
    final debt = debts.value?.where((debt) => debt.id == debtId).firstOrNull;

    if (debt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: debts.hasError && !debts.isLoading
            ? StateMessage(
                icon: Icons.cloud_off_outlined,
                text: debtErrorMessage(l10n, debts.error!),
                actionLabel: l10n.commonRetry,
                onAction: () => ref.invalidate(debtsProvider),
              )
            : debts.isLoading
            ? const Center(child: CircularProgressIndicator())
            : StateMessage(
                icon: Icons.search_off,
                text: l10n.debtsGone,
                actionLabel: l10n.commonBack,
                onAction: () => Navigator.of(context).pop(),
              ),
      );
    }

    final theme = Theme.of(context);
    final canPay = !debt.isSettled && !debt.isArchived;
    // El plan de cuotas de esta deuda, si es una compra a cuotas.
    final plan = ref
        .watch(recurringPaymentsProvider)
        .value
        ?.where((payment) => payment.debtId == debt.id)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.counterparty),
        actions: [
          IconButton(
            tooltip: l10n.debtsEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDebtForm(context, debt: debt),
          ),
          PopupMenuButton<_DebtMenuAction>(
            tooltip: l10n.commonOptions,
            onSelected: (_) =>
                _setArchived(context, ref, debt, archived: !debt.isArchived),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _DebtMenuAction.toggleArchived,
                child: Text(
                  debt.isArchived ? l10n.commonRestore : l10n.commonArchive,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SummaryCard(debt: debt),
          if (plan != null) ...[
            const SizedBox(height: 16),
            _PlanCard(plan: plan),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canPay ? () => showPaymentSheet(context, debt) : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.debtsRecordPayment),
          ),
          if (!canPay) ...[
            const SizedBox(height: 8),
            Text(
              debt.isSettled
                  ? l10n.debtsIsSettledNote
                  : l10n.debtsIsArchivedNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.debtsPaymentsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Payments(debt: debt),
        ],
      ),
    );
  }
}

/// El plan de cuotas de una compra a cuotas: cuál toca, cuándo, y el botón para
/// confirmar que se pagó.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final RecurringPayment plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = DateTime.now();
    final status = plan.statusOn(today);
    final color =
        recurringStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.debtsPlanTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              recurrenceSummary(l10n, plan),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(recurringStatusIcon(status), size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    recurringStatusText(l10n, plan, today),
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (plan.canPay) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => showConfirmPaymentSheet(context, plan),
                  child: Text(l10n.recurringPayAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final today = DateTime.now();
    final status = debt.statusOn(today);
    final statusColor =
        debtStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final statusIcon = debtStatusIcon(status);
    String money(double value) =>
        formats.money(value, currency: debt.currency);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debt.direction == DebtDirection.payable
                  ? l10n.debtsYouOweTo(debt.counterparty)
                  : l10n.debtsOwesYou(debt.counterparty),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(debt.remaining),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(l10n.debtsRemainingWord, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: debt.progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.debtsPaidAmount(money(debt.paid)),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  l10n.debtsTotalAmount(money(debt.amount)),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                if (statusIcon != null) ...[
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  debtStatusText(l10n, debt, today),
                  style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.debtsSince(formats.fullDate(debt.startDate)),
              style: theme.textTheme.bodySmall,
            ),
            if (debt.dueDate != null)
              Text(
                l10n.debtStatusDueOn(formats.fullDate(debt.dueDate!)),
                style: theme.textTheme.bodySmall,
              ),
            if (debt.notes != null && debt.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(debt.notes!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _Payments extends ConsumerWidget {
  const _Payments({required this.debt});

  final Debt debt;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DebtPayment payment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.debtsPaymentDeleteTitle),
        content: Text(l10n.debtsPaymentDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(debtsProvider.notifier).deletePayment(payment.transactionId);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(debtErrorMessage(l10n, error))),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.debtsPaymentDeleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final payments = ref.watch(debtPaymentsProvider(debt.id));
    final accountNames = ref.watch(accountNamesProvider);

    return payments.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(debtErrorMessage(l10n, error)),
          trailing: TextButton(
            onPressed: () => ref.invalidate(debtPaymentsProvider(debt.id)),
            child: Text(l10n.commonRetry),
          ),
        ),
      ),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.debtsPaymentsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final payment in list)
                    ListTile(
                      title: Text(
                        formats.money(payment.amount, currency: debt.currency),
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        [
                          formats.fullDate(payment.date),
                          accountNames[payment.accountId] ?? l10n.commonAccount,
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.debtsPaymentDeleteTooltip,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, payment),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
