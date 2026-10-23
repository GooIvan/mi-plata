import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
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
  });

  final Account account;
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
        leading: CircleAvatar(child: Icon(account.type.icon)),
        title: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          account.isArchived
              ? '${account.type.label(l10n)} · ${l10n.accountsArchivedTag}'
              : account.type.label(l10n),
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
                color: isNegative ? theme.colorScheme.error : null,
              ),
            ),
            PopupMenuButton<AccountMenuAction>(
              tooltip: l10n.commonOptions,
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
