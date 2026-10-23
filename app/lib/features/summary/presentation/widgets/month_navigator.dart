import 'package:flutter/material.dart';

import '../../../../core/format/date_format.dart';

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
          tooltip: 'Mes anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Text(
          formatMonth(month),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
