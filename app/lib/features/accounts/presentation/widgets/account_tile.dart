import 'package:flutter/material.dart';

import '../../../../core/format/money_format.dart';
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
    final isNegative = account.currentBalance < 0;

    return Opacity(
      opacity: account.isArchived ? 0.6 : 1,
      child: ListTile(
        leading: CircleAvatar(child: Icon(account.type.icon)),
        title: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          account.isArchived
              ? '${account.type.label} · Archivada'
              : account.type.label,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(account.currentBalance, currency: account.currency),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isNegative ? theme.colorScheme.error : null,
              ),
            ),
            PopupMenuButton<AccountMenuAction>(
              tooltip: 'Opciones',
              onSelected: (action) => switch (action) {
                AccountMenuAction.edit => onEdit(),
                AccountMenuAction.toggleArchived => onToggleArchived(),
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: AccountMenuAction.edit,
                  child: Text('Editar'),
                ),
                PopupMenuItem(
                  value: AccountMenuAction.toggleArchived,
                  child: Text(account.isArchived ? 'Restaurar' : 'Archivar'),
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
