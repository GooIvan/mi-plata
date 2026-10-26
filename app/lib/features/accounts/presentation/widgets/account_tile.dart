import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/account.dart';
import '../account_type_ui.dart';

enum AccountMenuAction { edit, toggleArchived }

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.onEdit,
    required this.onToggleArchived,
    this.baseCurrency,
  });

  final Account account;

  /// La moneda base: si la cuenta es de otra, se dice cuál.
  final String? baseCurrency;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isNegative = account.currentBalance < 0;

    return Opacity(
      opacity: account.isArchived ? 0.6 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 6),
        leading: IconBadge(
          icon: account.type.icon,
          color: account.type.color(theme.brightness),
        ),
        title: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            account.type.label(l10n),
            if (baseCurrency != null && account.currency != baseCurrency)
              account.currency,
            if (account.isArchived) l10n.accountsArchivedTag,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.formats.money(
                account.currentBalance,
                currency: account.currency,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isNegative ? theme.colorScheme.error : null,
              ),
            ),
            PopupMenuButton<AccountMenuAction>(
              tooltip: l10n.commonOptions,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              iconSize: 20,
              onSelected: (action) => switch (action) {
                AccountMenuAction.edit => onEdit(),
                AccountMenuAction.toggleArchived => onToggleArchived(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: AccountMenuAction.edit,
                  child: Text(l10n.commonEdit),
                ),
                PopupMenuItem(
                  value: AccountMenuAction.toggleArchived,
                  child: Text(
                    account.isArchived
                        ? l10n.commonRestore
                        : l10n.commonArchive,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
