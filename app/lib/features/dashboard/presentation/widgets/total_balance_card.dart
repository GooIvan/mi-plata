import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/account_totals.dart';

/// El dinero total: la suma de los saldos de las cuentas activas.
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({
    super.key,
    required this.accounts,
    required this.onRetry,
    required this.onCreateAccount,
  });

  final AsyncValue<List<Account>> accounts;
  final VoidCallback onRetry;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: colors.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.onPrimaryContainer),
          child: accounts.when(
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.dashboardLoadMoneyError),
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
            data: (all) {
              final active = all.where((account) => !account.isArchived).toList();
              if (active.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.dashboardNoAccounts),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onCreateAccount,
                      child: Text(context.l10n.accountsCreateButton),
                    ),
                  ],
                );
              }
              return _Totals(accounts: active);
            },
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = context.formats;

    // El peso colombiano primero; cualquier otra moneda, debajo.
    final totals = AccountTotals.centsByCurrency(accounts).entries.toList()
      ..sort((a, b) {
        if (a.key == 'COP') return -1;
        if (b.key == 'COP') return 1;
        return a.key.compareTo(b.key);
      });
    final main = totals.first;
    final others = totals.skip(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.dashboardTotalMoney,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          formats.money(main.value / 100, currency: main.key),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: main.value < 0 ? theme.colorScheme.error : null,
          ),
        ),
        for (final other in others)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formats.money(other.value / 100, currency: other.key),
              style: theme.textTheme.titleLarge,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          context.l10n.dashboardAccountsCount(accounts.length),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
