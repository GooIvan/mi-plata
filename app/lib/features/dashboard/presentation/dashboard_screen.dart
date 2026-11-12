import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/finance_colors.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/presentation/budget_providers_overview.dart';
import '../../currency/presentation/currency_providers.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../savings/presentation/goals_providers.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/presentation/summary_providers.dart';
import '../../transactions/presentation/transaction_error_message.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../debts/presentation/debts_providers.dart';
import 'widgets/accounts_strip.dart';
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
    final thisMonth = SummaryCalculator.monthStart(DateTime.now());
    final monthTotals = ref.watch(monthlyTotalsProvider(thisMonth)).value;
    final rates = converter.value;
    final month = monthTotals == null || rates == null
        ? null
        : SummaryCalculator.forMonth(monthTotals, thisMonth, rates);
    final accountNames = ref.watch(accountNamesProvider);
    final accountCurrencies = ref.watch(accountCurrenciesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final l10n = context.l10n;

    final activeAccounts =
        accounts.value?.where((account) => !account.isArchived).toList() ??
        const <Account>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const _Logo(),
            const SizedBox(width: 10),
            const Text('mi-plata'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ProfileButton(
              email: auth.currentUser?.email,
              onTap: () => context.push(AppRoutes.settings),
            ),
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
            onCreateAccount: () => context.go(AppRoutes.accounts),
            month: month,
          ),
          if (activeAccounts.isNotEmpty) ...[
            _SectionHeader(
              title: l10n.accountsTitle,
              actionLabel: l10n.commonSeeAll,
              onAction: () => context.go(AppRoutes.accounts),
            ),
            AccountsStrip(
              accounts: activeAccounts,
              onTap: () => context.go(AppRoutes.accounts),
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
            onAction: () => context.go(AppRoutes.goals),
          ),
          GoalsSummaryCard(
            goals: goals,
            onOpenAll: () => context.go(AppRoutes.goals),
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
            onAction: () => context.go(AppRoutes.transactions),
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
        // Las pestañas viven a la vez: sin etiqueta de héroe compartida.
        heroTag: null,
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
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// La marca: un cuadrado con el degradado de la tarjeta principal.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: finance.heroGradient,
        ),
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: 18,
        color: finance.onHero,
      ),
    );
  }
}

/// La inicial del correo, que lleva a los ajustes.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.email, required this.onTap});

  final String? email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = (email?.trim().isNotEmpty ?? false)
        ? email!.trim()[0].toUpperCase()
        : null;

    // El correo queda en el tooltip: así se sabe con qué cuenta se entró.
    return Tooltip(
      message: email ?? '',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: initial == null
              ? const Icon(Icons.person_outline, size: 20)
              : Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
