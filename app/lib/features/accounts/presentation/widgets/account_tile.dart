import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/theme/finance_colors.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/account.dart';
import '../../domain/card_statement.dart';
import '../../domain/card_usage.dart';
import '../account_type_ui.dart';
import '../card_actions.dart';
import '../card_providers.dart';
import 'card_installments_sheet.dart';

enum AccountMenuAction { edit, toggleArchived }

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.onEdit,
    required this.onToggleArchived,
    this.baseCurrency,
    this.today,
  });

  final Account account;

  /// La moneda base: si la cuenta es de otra, se dice cuál.
  final String? baseCurrency;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchived;

  /// El día de hoy, para las fechas de una tarjeta; null es el día de verdad.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isNegative = account.currentBalance < 0;

    final tile = ListTile(
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
      );

    return Opacity(
      opacity: account.isArchived ? 0.6 : 1,
      child: account.isCard
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [tile, CardSummary(account: account, today: today)],
            )
          : tile,
    );
  }
}

/// Lo que se ve de una tarjeta además de su saldo: cuánto del cupo se usó, lo
/// que queda, las fechas de corte y de pago y lo que falta pagar del último
/// corte (con un botón para pagarlo). No muestra nada si la tarjeta no tiene
/// ni cupo ni fechas.
class CardSummary extends ConsumerWidget {
  const CardSummary({super.key, required this.account, this.today});

  final Account account;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = CardUsage.of(account);
    final calendar = account.cardCalendar;
    if (!usage.hasLimit && calendar == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final now = today ?? DateTime.now();
    final scheme = theme.colorScheme;

    // El color acompaña al texto y al ícono, nunca los reemplaza.
    final levelColor = switch (usage.level) {
      CardLevel.ok => account.type.color(theme.brightness),
      CardLevel.high => context.finance.warning,
      CardLevel.over => scheme.error,
    };
    final small = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usage.hasLimit) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usage.ratio!.clamp(0.0, 1.0),
                minHeight: 8,
                color: levelColor,
                backgroundColor: levelColor.withValues(alpha: 0.16),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.accountsCardUsedOf(
                    formats.money(
                      usage.usedCents / 100,
                      currency: account.currency,
                    ),
                    formats.money(
                      usage.limitCents! / 100,
                      currency: account.currency,
                    ),
                  ),
                  style: small,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (usage.level != CardLevel.ok) ...[
                      Icon(
                        usage.level == CardLevel.over
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: levelColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      usage.level == CardLevel.over
                          ? l10n.accountsCardOverLimit(
                              formats.money(
                                -usage.availableCents! / 100,
                                currency: account.currency,
                              ),
                            )
                          : l10n.accountsCardAvailable(
                              formats.money(
                                usage.availableCents! / 100,
                                currency: account.currency,
                              ),
                            ),
                      style: small?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: usage.level == CardLevel.ok
                            ? scheme.onSurface
                            : levelColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (calendar != null) ...[
            SizedBox(height: usage.hasLimit ? 6 : 0),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.accountsCardDates(
                      formats.dayMonth(calendar.nextStatement(now)),
                      formats.dayMonth(calendar.nextPayment(now)),
                    ),
                    style: small,
                  ),
                ),
              ],
            ),
            // Es un extra: mientras carga o si falla, simplemente no aparece.
            if (!account.isArchived)
              if (ref.watch(cardStatementProvider(account.id)).value
                  case final statement?)
                _StatementRow(account: account, statement: statement, today: now),
          ],
          if (!account.isArchived)
            if (activeInstallments(
              ref.watch(cardInstallmentPlansProvider).value ?? const [],
              account,
              today: now,
            ) case final plans when plans.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => showCardInstallmentsSheet(context, account),
                  icon: const Icon(Icons.splitscreen_outlined, size: 16),
                  label: Text(l10n.cardInstallmentsButton(plans.length)),
                ),
              ),
        ],
      ),
    );
  }
}

/// Lo que falta pagar del último corte y el botón para pagarlo; o el aviso de
/// que no se debe nada de él.
class _StatementRow extends ConsumerWidget {
  const _StatementRow({
    required this.account,
    required this.statement,
    required this.today,
  });

  final Account account;
  final CardStatement statement;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final formats = context.formats;

    if (statement.isPaidUp) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: context.finance.income),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.accountsCardPaidUp,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final overdue = statement.isOverdue(today);
    final amount = formats.money(
      statement.dueCents / 100,
      currency: account.currency,
    );
    final color = overdue ? scheme.error : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            overdue ? Icons.error_outline : Icons.payments_outlined,
            size: 16,
            color: overdue ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              overdue
                  ? l10n.accountsCardOverdue(
                      formats.dayMonth(statement.dueDate),
                      amount,
                    )
                  : l10n.accountsCardDue(amount),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => showPayCard(
              context,
              ref,
              account,
              amount: statement.dueCents / 100,
            ),
            child: Text(l10n.accountsCardPay),
          ),
        ],
      ),
    );
  }
}
