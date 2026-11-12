import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/theme/finance_colors.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../currency/domain/currency.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_type.dart';
import '../transaction_type_ui.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accountNames,
    required this.accountCurrencies,
    required this.categoryNames,
    required this.onTap,
  });

  final Transaction transaction;
  final Map<String, String> accountNames;

  /// La moneda de cada cuenta: un movimiento está en la moneda de su cuenta.
  final Map<String, String> accountCurrencies;
  final Map<String, String> categoryNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final type = transaction.type;

    final account = accountNames[transaction.accountId] ?? l10n.commonAccount;
    final destination =
        accountNames[transaction.destinationAccountId] ?? l10n.commonAccount;
    final category = categoryNames[transaction.categoryId];
    final description = transaction.description;
    final hasDescription = description != null && description.isNotEmpty;

    final title = hasDescription ? description : (category ?? type.label(l10n));
    final formats = context.formats;
    final currency = accountCurrencies[transaction.accountId] ?? defaultCurrency;
    final received = transaction.destinationAmount;
    final subtitle = type == TransactionType.transfer
        ? [
            '$account → $destination',
            // Entre monedas distintas, también lo que llegó.
            if (received != null)
              l10n.transactionsReceives(
                formats.money(
                  received,
                  currency:
                      accountCurrencies[transaction.destinationAccountId] ??
                      defaultCurrency,
                ),
              ),
          ].join(' · ')
        : [if (hasDescription && category != null) category, account].join(' · ');

    final finance = context.finance;
    final (sign, color) = switch (type) {
      TransactionType.income => ('+', finance.income),
      TransactionType.expense => ('-', finance.expense),
      TransactionType.transfer => ('', finance.transfer),
    };

    return ListTile(
      leading: IconBadge(icon: type.icon, color: color),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Dos líneas: una transferencia entre monedas también dice lo que llegó.
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$sign${formats.money(transaction.amount, currency: currency)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}
