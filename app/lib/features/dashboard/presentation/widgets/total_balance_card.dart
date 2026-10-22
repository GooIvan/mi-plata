import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/money_format.dart';
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
                const Text('No se pudo cargar tu dinero.'),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
            data: (all) {
              final active = all.where((account) => !account.isArchived).toList();
              if (active.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aún no tienes cuentas'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onCreateAccount,
                      child: const Text('Crear cuenta'),
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
        Text('Dinero total', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          formatMoney(main.value / 100, currency: main.key),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: main.value < 0 ? theme.colorScheme.error : null,
          ),
        ),
        for (final other in others)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formatMoney(other.value / 100, currency: other.key),
              style: theme.textTheme.titleLarge,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          accounts.length == 1 ? 'En 1 cuenta' : 'En ${accounts.length} cuentas',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
