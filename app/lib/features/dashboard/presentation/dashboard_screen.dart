import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money_format.dart';
import '../../../core/router/app_routes.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_type_ui.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../transactions/presentation/transaction_error_message.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import 'widgets/total_balance_card.dart';

/// Vista principal: el dinero total, las cuentas y los últimos movimientos.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _recentCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authRepositoryProvider);
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    final accountNames = ref.watch(accountNamesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final theme = Theme.of(context);

    final activeAccounts =
        accounts.value?.where((account) => !account.isArchived).toList() ??
        const <Account>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('mi-plata'),
            if (auth.currentUser?.email case final email?)
              Text(email, style: theme.textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push(AppRoutes.categories),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TotalBalanceCard(
            accounts: accounts,
            onRetry: () => ref.invalidate(accountsProvider),
            onCreateAccount: () => context.push(AppRoutes.accounts),
          ),
          if (activeAccounts.isNotEmpty) ...[
            _SectionHeader(
              title: 'Cuentas',
              actionLabel: 'Ver todas',
              onAction: () => context.push(AppRoutes.accounts),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final account in activeAccounts)
                    ListTile(
                      leading: CircleAvatar(child: Icon(account.type.icon)),
                      title: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        formatMoney(
                          account.currentBalance,
                          currency: account.currency,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: account.currentBalance < 0
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      onTap: () => context.push(AppRoutes.accounts),
                    ),
                ],
              ),
            ),
          ],
          _SectionHeader(
            title: 'Últimos movimientos',
            actionLabel: 'Ver todos',
            onAction: () => context.push(AppRoutes.transactions),
          ),
          transactions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(transactionErrorMessage(error)),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: const Text('Reintentar'),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? const Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(title: Text('Aún no registras movimientos.')),
                  )
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final transaction in list.take(_recentCount))
                          TransactionTile(
                            transaction: transaction,
                            accountNames: accountNames,
                            categoryNames: categoryNames,
                            onTap: () => showTransactionForm(
                              context,
                              transaction: transaction,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo movimiento'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
