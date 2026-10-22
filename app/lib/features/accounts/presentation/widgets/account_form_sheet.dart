import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_banner.dart';
import '../../domain/account.dart';
import '../../domain/account_type.dart';
import '../../domain/account_validators.dart';
import '../../domain/amount_parser.dart';
import '../account_error_message.dart';
import '../account_type_ui.dart';
import '../accounts_providers.dart';

/// Abre el formulario para crear una cuenta, o para editar [account].
Future<void> showAccountForm(BuildContext context, {Account? account}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountFormSheet(account: account),
  );
}

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account?.name);
  late final _balance = TextEditingController(
    text: widget.account == null
        ? ''
        : AmountParser.toInput(widget.account!.initialBalance),
  );
  late AccountType _type = widget.account?.type ?? AccountType.bank;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.account != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final accounts = ref.read(accountsProvider.notifier);
    final name = _name.text.trim();
    final initialBalance = AmountParser.parse(_balance.text)!;

    try {
      if (_isEditing) {
        await accounts.edit(
          id: widget.account!.id,
          name: name,
          type: _type,
          initialBalance: initialBalance,
        );
      } else {
        await accounts.create(
          name: name,
          type: _type,
          initialBalance: initialBalance,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = accountErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Editar cuenta' : 'Nueva cuenta',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: AccountValidators.name,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Bancolombia ahorros',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tipo', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in AccountType.values)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balance,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              textInputAction: TextInputAction.done,
              validator: AccountValidators.initialBalance,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Saldo inicial',
                hintText: 'Ej: 1.500.000',
                prefixText: r'$ ',
                helperText: 'Déjalo vacío si empieza en cero',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
