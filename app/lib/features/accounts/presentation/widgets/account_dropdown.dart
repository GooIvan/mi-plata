import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../currency/presentation/currency_providers.dart';
import '../../domain/account.dart';
import '../account_label.dart';

/// Un selector de cuenta. Marca las archivadas, por si el movimiento que se
/// edita todavía las usa.
class AccountDropdown extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(currencyConverterProvider).value?.base;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Text(
              accountLabel(context.l10n, account, baseCurrency: base),
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
