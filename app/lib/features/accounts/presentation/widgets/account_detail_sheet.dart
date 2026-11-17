import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../currency/presentation/currency_ui.dart';
import '../../../transactions/domain/transaction_filter.dart';
import '../../../transactions/presentation/transaction_list_providers.dart';
import '../../domain/account.dart';
import '../account_type_ui.dart';
import '../accounts_providers.dart';
import 'account_form_sheet.dart';
import 'account_tile.dart';

/// Qué eligió el usuario en el detalle de una cuenta.
enum _AccountDetailAction { edit, movements }

/// Abre el detalle de una cuenta, solo para verla. Desde ahí se pasa a editarla
/// con *Editar*, o a ver sus movimientos: tocar una cuenta ya no abre la edición
/// de golpe.
Future<void> showAccountDetail(BuildContext context, Account account) async {
  final action = await showModalBottomSheet<_AccountDetailAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountDetailSheet(account: account),
  );
  if (!context.mounted) return;
  switch (action) {
    case _AccountDetailAction.edit:
      await showAccountForm(context, account: account);
    case _AccountDetailAction.movements:
      context.go(AppRoutes.transactions);
    case null:
      break;
  }
}

class AccountDetailSheet extends ConsumerWidget {
  const AccountDetailSheet({super.key, required this.account, this.today});

  /// La cuenta tal como se tocó; el detalle usa la versión más nueva si hay.
  final Account account;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    // El saldo cambia con cada movimiento: se lee el de ahora.
    final current =
        ref
            .watch(accountsProvider)
            .value
            ?.where((a) => a.id == account.id)
            .firstOrNull ??
        account;
    final isNegative = current.currentBalance < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(
                icon: current.type.icon,
                color: current.type.color(theme.brightness),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        current.type.label(l10n),
                        if (current.isArchived) l10n.accountsArchivedTag,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.accountsDetailCurrentBalance,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formats.money(current.currentBalance, currency: current.currency),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isNegative ? theme.colorScheme.error : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Una tarjeta trae además su cupo, sus fechas y lo que falta pagar.
          if (current.isCard) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CardSummary(account: current, today: today),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: Icons.payments_outlined,
                  label: l10n.currencyLabel,
                  value: currencyOptionLabel(l10n, current.currency),
                ),
                _Row(
                  icon: Icons.flag_outlined,
                  label: l10n.accountsDetailInitialBalance,
                  value: formats.money(
                    current.initialBalance,
                    currency: current.currency,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_AccountDetailAction.edit),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.commonEdit),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // Actividad se abre ya filtrada por esta cuenta.
              ref
                  .read(transactionFilterProvider.notifier)
                  .set(TransactionFilter(accountId: current.id));
              Navigator.of(context).pop(_AccountDetailAction.movements);
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l10n.accountsDetailMovements),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
