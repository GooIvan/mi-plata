import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../domain/account.dart';
import 'account_error_message.dart';
import 'accounts_providers.dart';
import 'widgets/account_form_sheet.dart';
import 'widgets/account_tile.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  Future<void> _setArchived(Account account, {required bool archived}) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(accountsProvider.notifier)
          .setArchived(account.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(accountErrorMessage(error))));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(archived ? 'Cuenta archivada' : 'Cuenta restaurada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _setArchived(account, archived: !archived),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Ocultar archivadas' : 'Mostrar archivadas',
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: accountErrorMessage(error),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(accountsProvider),
        ),
        data: _buildList,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
    );
  }

  Widget _buildList(List<Account> all) {
    if (all.isEmpty) {
      return StateMessage(
        icon: Icons.account_balance_wallet_outlined,
        text: 'Aún no tienes cuentas.\nCrea la primera para empezar.',
        actionLabel: 'Crear cuenta',
        onAction: () => showAccountForm(context),
      );
    }

    // Las activas primero; las archivadas, al final y solo si se piden.
    final visible = [
      ...all.where((account) => !account.isArchived),
      if (_showArchived) ...all.where((account) => account.isArchived),
    ];

    if (visible.isEmpty) {
      return StateMessage(
        icon: Icons.inventory_2_outlined,
        text: 'Todas tus cuentas están archivadas.',
        actionLabel: 'Mostrar archivadas',
        onAction: () => setState(() => _showArchived = true),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final account = visible[index];
        return AccountTile(
          account: account,
          onEdit: () => showAccountForm(context, account: account),
          onToggleArchived: () =>
              _setArchived(account, archived: !account.isArchived),
        );
      },
    );
  }
}
