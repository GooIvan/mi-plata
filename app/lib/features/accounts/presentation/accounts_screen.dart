import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../currency/presentation/currency_providers.dart';
import '../domain/account.dart';
import 'account_error_message.dart';
import 'accounts_providers.dart';
import 'widgets/account_detail_sheet.dart';
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
    final l10n = context.l10n;

    try {
      await ref
          .read(accountsProvider.notifier)
          .setArchived(account.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(accountErrorMessage(l10n, error))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived ? l10n.accountsArchivedMessage : l10n.accountsRestoredMessage,
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => _setArchived(account, archived: !archived),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountsTitle),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? l10n.commonHideArchived
                : l10n.commonShowArchived,
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
          text: accountErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(accountsProvider),
        ),
        data: _buildList,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Las pestañas viven a la vez: sin etiqueta de héroe compartida.
        heroTag: null,
        onPressed: () => showAccountForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.accountsNew),
      ),
    );
  }

  Widget _buildList(List<Account> all) {
    final l10n = context.l10n;
    if (all.isEmpty) {
      return StateMessage(
        icon: Icons.account_balance_wallet_outlined,
        text: l10n.accountsEmpty,
        actionLabel: l10n.accountsCreateButton,
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
        text: l10n.accountsAllArchived,
        actionLabel: l10n.commonShowArchived,
        onAction: () => setState(() => _showArchived = true),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final account = visible[index];
        return Card(
          child: AccountTile(
            account: account,
            baseCurrency: ref.watch(currencyConverterProvider).value?.base,
            onEdit: () => showAccountForm(context, account: account),
            onShow: () => showAccountDetail(context, account),
            onToggleArchived: () =>
                _setArchived(account, archived: !account.isArchived),
          ),
        );
      },
    );
  }
}
