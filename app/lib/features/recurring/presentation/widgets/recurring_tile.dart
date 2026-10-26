import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../currency/domain/currency.dart';
import '../../domain/recurring_payment.dart';
import '../recurring_ui.dart';

/// Un pago recurrente en una lista: qué es, cuánto, cada cuánto y cómo va su
/// próxima fecha. Si pide atención, trae el botón para confirmar que se pagó.
class RecurringTile extends StatelessWidget {
  const RecurringTile({
    super.key,
    required this.payment,
    required this.today,
    required this.currency,
    required this.onTap,
    this.onPay,
  });

  final RecurringPayment payment;
  final DateTime today;

  /// La moneda de la cuenta de la que se paga.
  final String? currency;
  final VoidCallback onTap;

  /// Confirmar que se pagó. Null no muestra el botón.
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final status = payment.statusOn(today);
    final color =
        recurringStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final dimmed =
        status == RecurringStatus.paused || status == RecurringStatus.finished;

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.formats.money(
                      payment.amount,
                      currency: currency ?? defaultCurrency,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(recurringStatusIcon(status), size: 16, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      recurringStatusText(l10n, payment, today),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  recurrenceSummary(l10n, payment),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onPay != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onPay,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n.recurringPayAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
