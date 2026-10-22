import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/widgets/state_message.dart';
import '../domain/transaction.dart';
import 'transaction_error_message.dart';
import 'transaction_form_screen.dart';
import 'transactions_providers.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: transactionErrorMessage(error),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(transactionsProvider),
        ),
        data: (list) => list.isEmpty
            ? StateMessage(
                icon: Icons.receipt_long_outlined,
                text: 'Aún no registras movimientos.\nAnota el primero.',
                actionLabel: 'Registrar movimiento',
                onAction: () => showTransactionForm(context),
              )
            : _TransactionList(transactions: list),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo movimiento'),
      ),
    );
  }
}

/// Movimientos agrupados por día, con un encabezado en cada cambio de fecha.
class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountNames = ref.watch(accountNamesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final theme = Theme.of(context);

    // Cada elemento es el encabezado de un día (DateTime) o un movimiento.
    final items = <Object>[];
    DateTime? lastDay;
    for (final transaction in transactions) {
      if (lastDay == null || !DateUtils.isSameDay(lastDay, transaction.date)) {
        items.add(transaction.date);
        lastDay = transaction.date;
      }
      items.add(transaction);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              formatDay(item),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final transaction = item as Transaction;
        return TransactionTile(
          transaction: transaction,
          accountNames: accountNames,
          categoryNames: categoryNames,
          onTap: () => showTransactionForm(context, transaction: transaction),
        );
      },
    );
  }
}
