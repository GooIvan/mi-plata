import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/account.dart';

/// Un selector de cuenta. Marca las archivadas, por si el movimiento que se
/// edita todavía las usa.
class AccountDropdown extends StatelessWidget {
  const AccountDropdown({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  final List<Account> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Text(
              account.isArchived
                  ? context.l10n.accountsArchivedName(account.name)
                  : account.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (id) => id == null ? context.l10n.accountsChoose : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
