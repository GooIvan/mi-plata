import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/account_totals.dart';
import '../../../currency/domain/currency_converter.dart';
import '../../../currency/presentation/widgets/missing_rates_note.dart';

/// El dinero total: la suma de los saldos de las cuentas activas.
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({
    super.key,
    required this.accounts,
    required this.converter,
    required this.onRetry,
    required this.onCreateAccount,
  });

  final AsyncValue<List<Account>> accounts;

  /// La moneda base y las tasas con que se suma todo.
  final AsyncValue<CurrencyConverter> converter;
  final VoidCallback onRetry;
  final VoidCallback onCreateAccount;

  Widget _content(BuildContext context) {
    final failed =
        (accounts.hasError && !accounts.isLoading) ||
        (converter.hasError && !converter.isLoading);
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.dashboardLoadMoneyError),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      );
    }

    final all = accounts.value;
    final rates = converter.value;
    if (all == null || rates == null) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
    return _Totals(accounts: active, converter: rates);
  }

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
          child: _content(context),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.accounts, required this.converter});

  final List<Account> accounts;
  final CurrencyConverter converter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = context.formats;

    // Arriba, todo sumado en la moneda base; debajo, lo que hay en cada una de
    // las otras monedas, tal como está.
    final total = AccountTotals.inBase(accounts, converter);
    final others = AccountTotals.centsByCurrency(accounts).entries
        .where((entry) => entry.key != converter.base)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.dashboardTotalMoney,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          formats.money(total.cents / 100, currency: converter.base),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: total.cents < 0 ? theme.colorScheme.error : null,
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
        if (!total.isComplete) ...[
          const SizedBox(height: 8),
          MissingRatesNote(currencies: total.missing),
        ],
      ],
    );
  }
}
