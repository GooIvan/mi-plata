import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/recurring_payment.dart';
import 'recurring_detail_screen.dart';
import 'recurring_error_message.dart';
import 'recurring_form_screen.dart';
import 'recurring_providers.dart';
import 'recurring_ui.dart';
import 'widgets/confirm_payment_sheet.dart';
import 'widgets/recurring_tile.dart';

/// Los pagos recurrentes: lo que pide atención primero, luego lo que falta, y al
/// final lo pausado y lo terminado.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final payments = ref.watch(recurringPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringTitle)),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: recurringErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(recurringPaymentsProvider),
        ),
        data: (all) => all.isEmpty
            ? StateMessage(
                icon: Icons.autorenew,
                text: l10n.recurringEmpty,
                actionLabel: l10n.recurringEmptyAction,
                onAction: () => showRecurringForm(context),
              )
            : _List(payments: all),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringNew),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.payments});

  final List<RecurringPayment> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = DateTime.now();
    final currencies = ref.watch(accountCurrenciesProvider);

    final sorted = [...payments]..sort((a, b) => compareRecurring(a, b, today));
    final active = [
      for (final p in sorted)
        if (!p.isPaused && !p.isFinished) p,
    ];
    final other = [
      for (final p in sorted)
        if (p.isPaused || p.isFinished) p,
    ];

    Widget section(String title, List<RecurringPayment> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        for (final payment in list) ...[
          RecurringTile(
            payment: payment,
            today: today,
            currency: currencies[payment.accountId],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecurringDetailScreen(paymentId: payment.id),
              ),
            ),
            onPay: payment.needsAttention(today)
                ? () => showConfirmPaymentSheet(context, payment)
                : null,
          ),
          const Divider(height: 1),
        ],
      ],
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (active.isNotEmpty) section(l10n.recurringSectionActive, active),
        if (other.isNotEmpty) section(l10n.recurringSectionOther, other),
      ],
    );
  }
}
