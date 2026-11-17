import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/theme/finance_colors.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/presentation/card_providers.dart';
import '../../../currency/domain/currency.dart';
import '../../domain/transaction.dart';
import '../../domain/transaction_type.dart';
import '../transaction_form_screen.dart';
import '../transaction_type_ui.dart';
import '../transactions_providers.dart';

/// Abre el detalle de un movimiento, solo para verlo. Desde ahí se pasa a editar
/// con el botón *Editar*: tocar un movimiento ya no abre la edición de golpe.
Future<void> showTransactionDetail(
  BuildContext context,
  Transaction transaction,
) async {
  final edit = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionDetailSheet(transaction: transaction),
  );
  if (edit == true && context.mounted) {
    await showTransactionForm(context, transaction: transaction);
  }
}

class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final finance = context.finance;
    final type = transaction.type;

    final accountNames = ref.watch(accountNamesProvider);
    final accountCurrencies = ref.watch(accountCurrenciesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    // Si la compra se difirió en cuotas, también se dice (y cuánto fueron los
    // intereses).
    final plan = ref.watch(
      cardInstallmentPlansProvider.select(
        (plans) => plans.value
            ?.where((p) => p.transactionId == transaction.id)
            .firstOrNull,
      ),
    );

    final currency = accountCurrencies[transaction.accountId] ?? defaultCurrency;
    final (sign, color) = switch (type) {
      TransactionType.income => ('+', finance.income),
      TransactionType.expense => ('-', finance.expense),
      TransactionType.transfer => ('', finance.transfer),
    };
    final received = transaction.destinationAmount;
    final description = transaction.description;
    final category = categoryNames[transaction.categoryId];
    final account = accountNames[transaction.accountId] ?? l10n.commonAccount;
    final destination =
        accountNames[transaction.destinationAccountId] ?? l10n.commonAccount;

    String money(int cents, String code) =>
        formats.money(cents / 100, currency: code);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(icon: type.icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(type.label(l10n), style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$sign${formats.money(transaction.amount, currency: currency)}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (received != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.transactionsDetailReceived}: '
              '${formats.money(received, currency: accountCurrencies[transaction.destinationAccountId] ?? defaultCurrency)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: Icons.event_outlined,
                  label: l10n.commonDate,
                  value: formats.fullDate(transaction.date),
                ),
                if (type == TransactionType.transfer) ...[
                  _Row(
                    icon: Icons.north_east,
                    label: l10n.transactionsFrom,
                    value: account,
                  ),
                  _Row(
                    icon: Icons.south_west,
                    label: l10n.transactionsTo,
                    value: destination,
                  ),
                ] else ...[
                  _Row(
                    icon: Icons.account_balance_wallet_outlined,
                    label: l10n.commonAccount,
                    value: account,
                  ),
                  _Row(
                    icon: Icons.label_outline,
                    label: l10n.commonCategory,
                    value: category ?? l10n.commonNoCategory,
                  ),
                ],
                if (description != null && description.isNotEmpty)
                  _Row(
                    icon: Icons.notes_outlined,
                    label: l10n.transactionsDetailDescription,
                    value: description,
                  ),
                if (plan != null)
                  _Row(
                    icon: Icons.splitscreen_outlined,
                    label: l10n.cardInstallmentsTitle,
                    value: plan.interestCents > 0
                        ? l10n.cardInstallmentsQuoteInterest(
                            plan.installments,
                            money(plan.installmentCents, currency),
                            money(plan.totalCents, currency),
                            money(plan.interestCents, currency),
                          )
                        : l10n.cardInstallmentsQuote(
                            plan.installments,
                            money(plan.installmentCents, currency),
                            money(plan.totalCents, currency),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.commonEdit),
          ),
        ],
      ),
    );
  }
}

/// Una línea del detalle: ícono, qué es y su valor.
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
