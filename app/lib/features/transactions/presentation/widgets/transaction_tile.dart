import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_type.dart';
import '../transaction_type_ui.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accountNames,
    required this.categoryNames,
    required this.onTap,
  });

  final Transaction transaction;
  final Map<String, String> accountNames;
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
    final subtitle = type == TransactionType.transfer
        ? '$account → $destination'
        : [if (hasDescription && category != null) category, account].join(' · ');

    final (sign, color) = switch (type) {
      TransactionType.income => ('+', theme.colorScheme.primary),
      TransactionType.expense => ('-', theme.colorScheme.error),
      TransactionType.transfer => ('', theme.colorScheme.onSurfaceVariant),
    };

    return ListTile(
      leading: CircleAvatar(child: Icon(type.icon)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$sign${context.formats.money(transaction.amount)}',
        style: theme.textTheme.titleMedium?.copyWith(color: color),
      ),
      onTap: onTap,
    );
  }
}
