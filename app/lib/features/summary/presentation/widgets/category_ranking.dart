import 'package:flutter/material.dart';

import '../../../../core/format/money_format.dart';
import '../../domain/month_summary.dart';

/// El reparto por categoría como barras horizontales, de mayor a menor.
///
/// Las categorías son nominales, así que todas las barras llevan el mismo
/// color (el de la serie); la longitud ya dice cuánto pesa cada una. Las
/// cifras van en texto: la lista es también la versión en tabla del gráfico.
class CategoryRanking extends StatelessWidget {
  const CategoryRanking({
    super.key,
    required this.shares,
    required this.names,
    required this.color,
    required this.mutedColor,
  });

  final List<CategoryShare> shares;
  final Map<String, String> names;

  /// El color de la serie (ingresos o gastos).
  final Color color;

  /// Para "Otras" y "Sin categoría", que no son una categoría concreta.
  final Color mutedColor;

  String _name(CategoryShare share) => switch (share.kind) {
    ShareKind.category => names[share.categoryId] ?? 'Categoría',
    ShareKind.uncategorized => 'Sin categoría',
    ShareKind.other => 'Otras',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final share in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name(share),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatMoney(share.cents / 100),
                      style: theme.textTheme.titleSmall,
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        formatPercent(share.share),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      FractionallySizedBox(
                        // Una porción minúscula sigue viéndose.
                        widthFactor: share.share.clamp(0.015, 1.0),
                        child: Container(
                          height: 6,
                          color: share.kind == ShareKind.category
                              ? color
                              : mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "34 %", o "<1 %" si es una fracción pequeña pero no cero.
String formatPercent(double share) {
  final percent = (share * 100).round();
  if (percent == 0 && share > 0) return '<1 %';
  return '$percent %';
}
