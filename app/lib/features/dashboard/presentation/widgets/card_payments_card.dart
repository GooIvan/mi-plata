import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account_type.dart';
import '../../../accounts/domain/card_statement.dart';
import '../../../accounts/presentation/account_type_ui.dart';
import '../../../accounts/presentation/card_actions.dart';
import '../../../accounts/presentation/card_providers.dart';

/// Las tarjetas con algo por pagar de su último corte, la más urgente primero,
/// cada una con su botón para pagarla. Solo se dibuja si hay alguna.
class CardPaymentsCard extends ConsumerWidget {
  const CardPaymentsCard({super.key, required this.dues, this.today});

  final List<CardDue> dues;

  /// El día de hoy, para decir cuánto falta; null es el día de verdad.
  final DateTime? today;

  /// Cuántas tarjetas se muestran como máximo; el resto, en Cuentas.
  static const maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final formats = context.formats;
    final now = today ?? DateTime.now();
    final shown = dues.take(maxShown).toList();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final due in shown) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconBadge(
                    icon: Icons.credit_card_outlined,
                    color: AccountType.card.color(theme.brightness),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          due.account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        _WhenLine(statement: due.statement, today: now),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formats.money(
                          due.statement.dueCents / 100,
                          currency: due.account.currency,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: due.statement.isOverdue(now)
                              ? scheme.error
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => showPayCard(
                          context,
                          ref,
                          due.account,
                          amount: due.statement.dueCents / 100,
                        ),
                        child: Text(l10n.accountsCardPay),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (due != shown.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// "Vence en 5 días · 30 nov", o "Vencido desde el 30 nov", con ícono: el color
/// solo acompaña.
class _WhenLine extends StatelessWidget {
  const _WhenLine({required this.statement, required this.today});

  final CardStatement statement;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final date = context.formats.dayMonth(statement.dueDate);
    final overdue = statement.isOverdue(today);
    final days = statement.daysUntilDue(today);

    final when = switch (days) {
      0 => l10n.dashboardCardDueToday,
      1 => l10n.dashboardCardDueTomorrow,
      _ => l10n.dashboardCardDueIn(days),
    };
    final color = overdue ? scheme.error : scheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          overdue ? Icons.error_outline : Icons.event_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            overdue
                ? l10n.dashboardCardOverdue(date)
                : l10n.dashboardCardDueOn(when, date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
