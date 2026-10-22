import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/state_message.dart';
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
    try {
      await ref
          .read(debtsProvider.notifier)
          .setArchived(debt.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(debtErrorMessage(error))));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(archived ? 'Deuda archivada' : 'Deuda restaurada'),
        action: SnackBarAction(
          label: 'Deshacer',
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
    final debt = debts.value?.where((debt) => debt.id == debtId).firstOrNull;

    if (debt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: debts.hasError && !debts.isLoading
            ? StateMessage(
                icon: Icons.cloud_off_outlined,
                text: debtErrorMessage(debts.error!),
                actionLabel: 'Reintentar',
                onAction: () => ref.invalidate(debtsProvider),
              )
            : debts.isLoading
            ? const Center(child: CircularProgressIndicator())
            : StateMessage(
                icon: Icons.search_off,
                text: 'Esta deuda ya no existe.',
                actionLabel: 'Volver',
                onAction: () => Navigator.of(context).pop(),
              ),
      );
    }

    final theme = Theme.of(context);
    final canPay = !debt.isSettled && !debt.isArchived;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.counterparty),
        actions: [
          IconButton(
            tooltip: 'Editar deuda',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDebtForm(context, debt: debt),
          ),
          PopupMenuButton<_DebtMenuAction>(
            tooltip: 'Opciones',
            onSelected: (_) =>
                _setArchived(context, ref, debt, archived: !debt.isArchived),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _DebtMenuAction.toggleArchived,
                child: Text(debt.isArchived ? 'Restaurar' : 'Archivar'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SummaryCard(debt: debt),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canPay ? () => showPaymentSheet(context, debt) : null,
            icon: const Icon(Icons.add),
            label: const Text('Registrar abono'),
          ),
          if (!canPay) ...[
            const SizedBox(height: 8),
            Text(
              debt.isSettled
                  ? 'Esta deuda ya está saldada.'
                  : 'Está archivada: restáurala para registrar abonos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Abonos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Payments(debt: debt),
        ],
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
    final today = DateTime.now();
    final status = debt.statusOn(today);
    final statusColor =
        debtStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final statusIcon = debtStatusIcon(status);
    String money(double value) => formatMoney(value, currency: debt.currency);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debt.direction == DebtDirection.payable
                  ? 'Le debes a ${debt.counterparty}'
                  : '${debt.counterparty} te debe',
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
            Text('pendiente', style: theme.textTheme.bodySmall),
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
                Text('Pagado ${money(debt.paid)}', style: theme.textTheme.bodySmall),
                Text('Total ${money(debt.amount)}', style: theme.textTheme.bodySmall),
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
                  debtStatusText(debt, today),
                  style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Desde el ${formatFullDate(debt.startDate)}',
              style: theme.textTheme.bodySmall,
            ),
            if (debt.dueDate != null)
              Text(
                'Vence el ${formatFullDate(debt.dueDate!)}',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este abono?'),
        content: const Text(
          'Se elimina también su movimiento y el saldo de la cuenta se '
          'recalcula.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(debtsProvider.notifier).deletePayment(payment.transactionId);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(debtErrorMessage(error))));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Abono eliminado')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
          title: Text(debtErrorMessage(error)),
          trailing: TextButton(
            onPressed: () => ref.invalidate(debtPaymentsProvider(debt.id)),
            child: const Text('Reintentar'),
          ),
        ),
      ),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aún no hay abonos.',
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
                        formatMoney(payment.amount, currency: debt.currency),
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        [
                          formatFullDate(payment.date),
                          accountNames[payment.accountId] ?? 'Cuenta',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Eliminar abono',
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
