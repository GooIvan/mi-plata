import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../currency/domain/currency.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/recurring_payment.dart';
import 'recurring_error_message.dart';
import 'recurring_form_screen.dart';
import 'recurring_providers.dart';
import 'recurring_ui.dart';
import 'widgets/confirm_payment_sheet.dart';

enum _MenuAction { togglePause, delete }

/// El detalle de un pago recurrente: cuándo toca, cuánto, y los pagos que ya se
/// registraron.
class RecurringDetailScreen extends ConsumerWidget {
  const RecurringDetailScreen({super.key, required this.paymentId});

  final String paymentId;

  Future<void> _togglePause(
    BuildContext context,
    WidgetRef ref,
    RecurringPayment payment,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final pause = !payment.isPaused;
    try {
      await ref
          .read(recurringPaymentsProvider.notifier)
          .setPaused(payment.id, paused: pause);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(recurringErrorMessage(l10n, error))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pause ? l10n.recurringPausedMessage : l10n.recurringResumedMessage,
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringPayment payment,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recurringDeleteTitle),
        content: Text(
          payment.isInstallmentPlan
              ? l10n.recurringDeletePlanBody
              : l10n.recurringDeleteBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.recurringDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(recurringPaymentsProvider.notifier).delete(payment.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(recurringErrorMessage(l10n, error))),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recurringDeletedMessage)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final payments = ref.watch(recurringPaymentsProvider);
    final payment = payments.value
        ?.where((payment) => payment.id == paymentId)
        .firstOrNull;

    if (payment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: payments.hasError && !payments.isLoading
            ? StateMessage(
                icon: Icons.cloud_off_outlined,
                text: recurringErrorMessage(l10n, payments.error!),
                actionLabel: l10n.commonRetry,
                onAction: () => ref.invalidate(recurringPaymentsProvider),
              )
            : payments.isLoading
            ? const Center(child: CircularProgressIndicator())
            : StateMessage(
                icon: Icons.search_off,
                text: l10n.recurringGone,
                actionLabel: l10n.commonBack,
                onAction: () => Navigator.of(context).pop(),
              ),
      );
    }

    final theme = Theme.of(context);
    final formats = context.formats;
    final today = DateTime.now();
    final status = payment.statusOn(today);
    final statusColor =
        recurringStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final accountName = ref.watch(accountNamesProvider)[payment.accountId];
    final currency =
        ref.watch(accountCurrenciesProvider)[payment.accountId] ??
        defaultCurrency;
    final categoryName = ref.watch(categoryNamesProvider)[payment.categoryId];

    return Scaffold(
      appBar: AppBar(
        title: Text(payment.name),
        actions: [
          IconButton(
            tooltip: l10n.recurringEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showRecurringForm(context, payment: payment),
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: l10n.commonOptions,
            onSelected: (action) => switch (action) {
              _MenuAction.togglePause => _togglePause(context, ref, payment),
              _MenuAction.delete => _delete(context, ref, payment),
            },
            itemBuilder: (context) => [
              if (!payment.isFinished)
                PopupMenuItem(
                  value: _MenuAction.togglePause,
                  child: Text(
                    payment.isPaused ? l10n.recurringResume : l10n.recurringPause,
                  ),
                ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: Text(l10n.recurringDelete),
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
                  Text(
                    recurrenceSummary(l10n, payment),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formats.money(payment.amount, currency: currency),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(recurringStatusIcon(status), size: 18, color: statusColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          recurringStatusText(l10n, payment, today),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (payment.nextDueDate != null &&
                      status != RecurringStatus.later) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.recurringStatusLater(
                        formats.fullDate(payment.nextDueDate!),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (payment.debtRemaining != null)
                    Text(
                      l10n.recurringDebtRemaining(
                        formats.money(payment.debtRemaining!, currency: currency),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (accountName != null)
                    Text(
                      '${l10n.recurringAccountLabel}: $accountName',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (categoryName != null)
                    Text(
                      '${l10n.commonCategory}: $categoryName',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (payment.endDate != null)
                    Text(
                      l10n.recurringEndsOn(formats.fullDate(payment.endDate!)),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: payment.canPay
                ? () => showConfirmPaymentSheet(context, payment)
                : null,
            icon: const Icon(Icons.check),
            label: Text(l10n.recurringPayAction),
          ),
          const SizedBox(height: 24),
          Text(l10n.recurringHistoryTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _History(paymentId: payment.id),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final history = ref.watch(recurringHistoryProvider(paymentId));
    final accountNames = ref.watch(accountNamesProvider);
    final accountCurrencies = ref.watch(accountCurrenciesProvider);

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(recurringErrorMessage(l10n, error)),
          trailing: TextButton(
            onPressed: () => ref.invalidate(recurringHistoryProvider(paymentId)),
            child: Text(l10n.commonRetry),
          ),
        ),
      ),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.recurringHistoryEmpty,
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
                    ListTile(
                      title: Text(
                        formats.money(
                          transaction.amount,
                          currency:
                              accountCurrencies[transaction.accountId] ??
                              defaultCurrency,
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        [
                          formats.fullDate(transaction.date),
                          accountNames[transaction.accountId] ??
                              l10n.commonAccount,
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
