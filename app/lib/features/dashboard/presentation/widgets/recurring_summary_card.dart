import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../l10n/l10n.dart';
import '../../../recurring/domain/recurring_payment.dart';
import '../../../recurring/presentation/recurring_detail_screen.dart';
import '../../../recurring/presentation/recurring_ui.dart';
import '../../../recurring/presentation/widgets/confirm_payment_sheet.dart';
import '../../../recurring/presentation/widgets/recurring_tile.dart';

/// Los pagos recurrentes que piden atención (vencidos, de hoy o próximos), cada
/// uno con su botón para confirmar que se pagó. Si no hay ninguno, dice cuál es
/// el siguiente. Al tocar un pago abre su detalle.
class RecurringSummaryCard extends StatelessWidget {
  const RecurringSummaryCard({
    super.key,
    required this.payments,
    required this.accountCurrencies,
    required this.onOpenAll,
  });

  final AsyncValue<List<RecurringPayment>> payments;
  final Map<String, String> accountCurrencies;
  final VoidCallback onOpenAll;

  /// Cuántos pagos se muestran como máximo; el resto, en la lista completa.
  static const maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = DateTime.now();

    Widget text(String message) => InkWell(
      onTap: onOpenAll,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.autorenew,
              color: theme.colorScheme.primary,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: payments.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => text(l10n.recurringErrorInvalid),
        data: (all) {
          if (all.isEmpty) return text(l10n.recurringDashboardEmpty);

          final attention = [
            for (final payment in all)
              if (payment.needsAttention(today)) payment,
          ]..sort((a, b) => compareRecurring(a, b, today));
          if (attention.isNotEmpty) {
            return Column(
              children: [
                for (final payment in attention.take(maxShown)) ...[
                  RecurringTile(
                    payment: payment,
                    today: today,
                    currency: accountCurrencies[payment.accountId],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecurringDetailScreen(paymentId: payment.id),
                      ),
                    ),
                    onPay: () => showConfirmPaymentSheet(context, payment),
                  ),
                  if (payment != attention.take(maxShown).last)
                    const Divider(height: 1),
                ],
              ],
            );
          }

          // Nada urgente: el siguiente pago de los que siguen activos.
          final upcoming = [
            for (final payment in all)
              if (!payment.isPaused && !payment.isFinished) payment,
          ]..sort((a, b) => compareRecurring(a, b, today));
          if (upcoming.isEmpty) return text(l10n.recurringNothingSoon);

          final next = upcoming.first;
          return text(
            '${l10n.recurringNothingSoon}\n'
            '${l10n.recurringNextOne(next.name, context.formats.dayMonth(next.nextDueDate!))}',
          );
        },
      ),
    );
  }
}
