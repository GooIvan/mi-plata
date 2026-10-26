import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/theme/finance_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/account_totals.dart';
import '../../../currency/domain/currency_converter.dart';
import '../../../currency/presentation/widgets/missing_rates_note.dart';
import '../../../summary/domain/month_summary.dart';

/// El dinero total: la suma de los saldos de las cuentas activas.
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({
    super.key,
    required this.accounts,
    required this.converter,
    required this.onRetry,
    required this.onCreateAccount,
    this.month,
  });

  final AsyncValue<List<Account>> accounts;

  /// La moneda base y las tasas con que se suma todo.
  final AsyncValue<CurrencyConverter> converter;
  final VoidCallback onRetry;
  final VoidCallback onCreateAccount;

  /// Lo que entró y salió este mes. Es un extra: sin él, la tarjeta solo
  /// muestra el dinero total.
  final MonthSummary? month;

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
            style: TextButton.styleFrom(
              foregroundColor: context.finance.onHero,
              padding: EdgeInsets.zero,
            ),
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      );
    }

    final all = accounts.value;
    final rates = converter.value;
    if (all == null || rates == null) {
      return SizedBox(
        height: 96,
        child: Center(
          child: CircularProgressIndicator(color: context.finance.onHero),
        ),
      );
    }

    final active = all.where((account) => !account.isArchived).toList();
    if (active.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.dashboardNoAccounts),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.finance.onHero,
              foregroundColor: context.finance.heroGradient.first,
            ),
            onPressed: onCreateAccount,
            child: Text(context.l10n.accountsCreateButton),
          ),
        ],
      );
    }
    return _Totals(accounts: active, converter: rates, month: month);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final negative = switch (accounts.value) {
      final all? when converter.hasValue =>
        AccountTotals.inBase(
              all.where((account) => !account.isArchived).toList(),
              converter.value!,
            ).cents <
            0,
      _ => false,
    };
    // Un total en rojo se ve desde lejos: la tarjeta cambia de color.
    final gradient = negative
        ? [const Color(0xFFB3261E), const Color(0xFFE5484D)]
        : finance.heroGradient;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Dos círculos suaves, solo de adorno.
            Positioned(
              top: -50,
              right: -30,
              child: _Circle(size: 160, color: finance.onHero, alpha: 0.09),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _Circle(size: 150, color: finance.onHero, alpha: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: finance.onHero),
                child: _content(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.accounts,
    required this.converter,
    required this.month,
  });

  final List<Account> accounts;
  final CurrencyConverter converter;
  final MonthSummary? month;

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

    final onHero = context.finance.onHero;
    final soft = onHero.withValues(alpha: 0.78);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.dashboardTotalMoney,
                style: theme.textTheme.labelLarge?.copyWith(color: soft),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: onHero.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.l10n.dashboardAccountsCount(accounts.length),
                style: theme.textTheme.labelSmall?.copyWith(color: onHero),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formats.money(total.cents / 100, currency: converter.base),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: onHero,
            ),
          ),
        ),
        for (final other in others)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              formats.money(other.value / 100, currency: other.key),
              style: theme.textTheme.titleMedium?.copyWith(color: soft),
            ),
          ),
        if (!total.isComplete) ...[
          const SizedBox(height: 8),
          MissingRatesNote(currencies: total.missing, onColor: onHero),
        ],
        if (month case final month?) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FlowPill(
                  icon: Icons.south_west,
                  label: context.l10n.commonIncomes,
                  cents: month.incomeCents,
                  currency: month.currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FlowPill(
                  icon: Icons.north_east,
                  label: context.l10n.commonExpenses,
                  cents: month.expenseCents,
                  currency: month.currency,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lo que entró (o salió) este mes, sobre el degradado de la tarjeta.
class _FlowPill extends StatelessWidget {
  const _FlowPill({
    required this.icon,
    required this.label,
    required this.cents,
    required this.currency,
  });

  final IconData icon;
  final String label;
  final int cents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onHero = context.finance.onHero;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onHero.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onHero.withValues(alpha: 0.2),
            ),
            child: Icon(icon, size: 16, color: onHero),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onHero.withValues(alpha: 0.8),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.formats.money(cents / 100, currency: currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
