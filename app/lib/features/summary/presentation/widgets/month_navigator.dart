import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';

/// "‹ Octubre 2026 ›": para moverse de un mes al otro.
class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    super.key,
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;

  /// Falso en el mes actual: no hay nada que resumir en el futuro.
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: context.l10n.summaryPreviousMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Text(
          context.formats.month(month),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          tooltip: context.l10n.summaryNextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
