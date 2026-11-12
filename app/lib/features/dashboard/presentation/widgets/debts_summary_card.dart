import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/theme/finance_colors.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../debts/domain/debt.dart';
import '../../../debts/domain/debt_direction.dart';
import '../../../currency/domain/converted_total.dart';
import '../../../currency/domain/currency_converter.dart';
import '../../../currency/presentation/widgets/missing_rates_note.dart';
import '../../../debts/domain/debt_totals.dart';

/// Lo que debes y lo que te deben, de un vistazo. Al tocarla abre las deudas.
class DebtsSummaryCard extends StatelessWidget {
  const DebtsSummaryCard({
    super.key,
    required this.debts,
    required this.converter,
    required this.onTap,
  });

  final AsyncValue<List<Debt>> debts;

  /// La moneda base y las tasas con que se suma todo.
  final AsyncValue<CurrencyConverter> converter;
  final VoidCallback onTap;

  Widget _content(BuildContext context, ThemeData theme) {
    final failed =
        (debts.hasError && !debts.isLoading) ||
        (converter.hasError && !converter.isLoading);
    if (failed) return Text(context.l10n.dashboardDebtsLoadError);

    final all = debts.value;
    final rates = converter.value;
    if (all == null || rates == null) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (all.every((debt) => debt.isArchived)) {
      return Row(
        children: [
          IconBadge(
            icon: Icons.handshake_outlined,
            color: theme.colorScheme.primary,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.l10n.dashboardDebtsEmpty)),
          const Icon(Icons.chevron_right),
        ],
      );
    }

    final payable = DebtTotals.remaining(all, DebtDirection.payable, rates);
    final receivable = DebtTotals.remaining(
      all,
      DebtDirection.receivable,
      rates,
    );
    final missing = {...payable.missing, ...receivable.missing};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Amount(
                label: context.l10n.dashboardYouOwe,
                total: payable,
                currency: rates.base,
                color: context.finance.expense,
              ),
            ),
            Expanded(
              child: _Amount(
                label: context.l10n.dashboardOwedToYou,
                total: receivable,
                currency: rates.base,
                color: context.finance.income,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          MissingRatesNote(currencies: missing),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _content(context, theme),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.total,
    required this.currency,
    required this.color,
  });

  final String label;
  final ConvertedTotal total;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            context.formats.money(total.cents / 100, currency: currency),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
