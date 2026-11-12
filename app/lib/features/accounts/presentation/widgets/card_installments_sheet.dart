import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../transactions/presentation/transactions_providers.dart';
import '../../domain/account.dart';
import '../../domain/card_installment_plan.dart';
import '../card_providers.dart';

/// Las compras en cuotas de [card] que todavía tienen cuotas por cobrar.
List<CardInstallmentPlan> activeInstallments(
  Iterable<CardInstallmentPlan> plans,
  Account card, {
  DateTime? today,
}) {
  final calendar = card.cardCalendar;
  final now = today ?? DateTime.now();
  return [
    for (final plan in plans)
      if (plan.accountId == card.id &&
          (calendar == null || !plan.isFinished(calendar, now)))
        plan,
  ];
}

/// Abre la lista de las compras en cuotas de [card].
Future<void> showCardInstallmentsSheet(BuildContext context, Account card) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CardInstallmentsSheet(card: card),
  );
}

/// Cada compra en cuotas de la tarjeta: cuántas cuotas ya se cobraron, lo que
/// falta por cobrar y cuándo llega la próxima.
class CardInstallmentsSheet extends ConsumerWidget {
  const CardInstallmentsSheet({super.key, required this.card, this.today});

  final Account card;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final plans = activeInstallments(
      ref.watch(cardInstallmentPlansProvider).value ?? const [],
      card,
      today: today,
    );
    final categoryNames = ref.watch(categoryNamesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.cardInstallmentsTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(card.name, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.cardInstallmentsEmpty,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final plan in plans) ...[
              _PlanTile(
                plan: plan,
                card: card,
                title: (plan.description?.isNotEmpty ?? false)
                    ? plan.description!
                    : categoryNames[plan.categoryId] ??
                          l10n.cardInstallmentsUnnamed,
                today: today ?? DateTime.now(),
              ),
              if (plan != plans.last) const Divider(height: 24),
            ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.card,
    required this.title,
    required this.today,
  });

  final CardInstallmentPlan plan;
  final Account card;
  final String title;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final formats = context.formats;
    String money(int cents) =>
        formats.money(cents / 100, currency: card.currency);

    final calendar = card.cardCalendar;
    final statement = calendar?.lastStatement(today);
    final billed = calendar == null
        ? 0
        : plan.billedCuotas(calendar, statement!);
    final next = calendar == null
        ? null
        : plan.nextCuotaStatement(calendar, today);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(plan.totalCents),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${l10n.cardInstallmentsTag(plan.installments)} · '
          '${l10n.cardInstallmentsEach(money(plan.installmentCents))}',
          style: small,
        ),
        if (calendar != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: billed / plan.installments,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.cardInstallmentsProgress(billed, plan.installments),
            style: small,
          ),
          Text(
            l10n.cardInstallmentsRemaining(
              money(plan.unbilledCents(calendar, statement!)),
            ),
            style: small?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (next != null)
            Text(
              l10n.cardInstallmentsNext(formats.dayMonth(next)),
              style: small,
            ),
        ],
      ],
    );
  }
}
