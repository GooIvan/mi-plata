import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/money_format.dart';
import '../../../debts/domain/debt.dart';
import '../../../debts/domain/debt_direction.dart';
import '../../../debts/domain/debt_totals.dart';

/// Lo que debes y lo que te deben, de un vistazo. Al tocarla abre las deudas.
class DebtsSummaryCard extends StatelessWidget {
  const DebtsSummaryCard({super.key, required this.debts, required this.onTap});

  final AsyncValue<List<Debt>> debts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: debts.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => const Text('No se pudieron cargar las deudas.'),
            data: (all) {
              if (all.every((debt) => debt.isArchived)) {
                return Row(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Registra lo que debes o te deben'),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _Amount(
                      label: 'Debes',
                      cents: DebtTotals.remainingCents(all, DebtDirection.payable),
                    ),
                  ),
                  Expanded(
                    child: _Amount(
                      label: 'Te deben',
                      cents: DebtTotals.remainingCents(
                        all,
                        DebtDirection.receivable,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(cents / 100),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
