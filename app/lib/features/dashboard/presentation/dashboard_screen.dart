import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formats.dart';
import '../../../core/router/app_routes.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_type_ui.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/presentation/budget_providers_overview.dart';
import '../../currency/presentation/currency_providers.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../savings/presentation/goals_providers.dart';
import '../../summary/domain/month_summary.dart';
import '../../transactions/presentation/transaction_error_message.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../debts/presentation/debts_providers.dart';
import 'widgets/budget_summary_card.dart';
import 'widgets/debts_summary_card.dart';
import 'widgets/goals_summary_card.dart';
import 'widgets/recurring_summary_card.dart';
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
    final debts = ref.watch(debtsProvider);
    final converter = ref.watch(currencyConverterProvider);
    final recurring = ref.watch(recurringPaymentsProvider);
    final goals = ref.watch(goalProgressProvider);
    // Es un extra: mientras carga o si falla, simplemente no aparece.
    final budgets = ref
        .watch(
          budgetOverviewProvider(SummaryCalculator.monthStart(DateTime.now())),
        )
        .value;
    final accountNames = ref.watch(accountNamesProvider);
    final accountCurrencies = ref.watch(accountCurrenciesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;

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
            tooltip: l10n.dashboardSummaryTooltip,
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push(AppRoutes.summary),
          ),
          IconButton(
            tooltip: l10n.budgetsTitle,
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => context.push(AppRoutes.budgets),
          ),
          IconButton(
            tooltip: l10n.categoriesTitle,
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push(AppRoutes.categories),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TotalBalanceCard(
            accounts: accounts,
            converter: converter,
            onRetry: () {
              ref.invalidate(accountsProvider);
              ref.invalidate(currencyConverterProvider);
            },
            onCreateAccount: () => context.push(AppRoutes.accounts),
          ),
          if (activeAccounts.isNotEmpty) ...[
            _SectionHeader(
              title: l10n.accountsTitle,
              actionLabel: l10n.commonSeeAll,
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
                        formats.money(
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
            title: l10n.recurringTitle,
            actionLabel: l10n.commonSeeAllMasculine,
            onAction: () => context.push(AppRoutes.recurring),
          ),
          RecurringSummaryCard(
            payments: recurring,
            accountCurrencies: accountCurrencies,
            onOpenAll: () => context.push(AppRoutes.recurring),
          ),
          if (budgets != null && budgets.hasBudgets) ...[
            _SectionHeader(
              title: l10n.budgetsTitle,
              actionLabel: l10n.commonSeeAllMasculine,
              onAction: () => context.push(AppRoutes.budgets),
            ),
            BudgetSummaryCard(
              overview: budgets,
              onTap: () => context.push(AppRoutes.budgets),
            ),
          ],
          _SectionHeader(
            title: l10n.goalsTitle,
            actionLabel: l10n.commonSeeAll,
            onAction: () => context.push(AppRoutes.goals),
          ),
          GoalsSummaryCard(
            goals: goals,
            onOpenAll: () => context.push(AppRoutes.goals),
          ),
          _SectionHeader(
            title: l10n.debtsTitle,
            actionLabel: l10n.commonSeeAll,
            onAction: () => context.push(AppRoutes.debts),
          ),
          DebtsSummaryCard(
            debts: debts,
            converter: converter,
            onTap: () => context.push(AppRoutes.debts),
          ),
          _SectionHeader(
            title: l10n.dashboardRecentTransactions,
            actionLabel: l10n.commonSeeAllMasculine,
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
                title: Text(transactionErrorMessage(l10n, error)),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: Text(l10n.commonRetry),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(title: Text(l10n.dashboardNoTransactions)),
                  )
                : Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final transaction in list.take(_recentCount))
                          TransactionTile(
                            transaction: transaction,
                            accountNames: accountNames,
                            accountCurrencies: accountCurrencies,
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
        label: Text(l10n.transactionsNew),
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
