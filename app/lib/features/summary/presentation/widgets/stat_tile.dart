import 'package:flutter/material.dart';

/// Una cifra con su etiqueta. [marker] es el color de la serie en el gráfico:
/// enlaza la tarjeta con la leyenda, pero el número va en la tinta del tema.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.marker,
    this.caption,
    this.captionIcon,
    this.captionIconColor,
    this.hero = false,
  });

  final String label;
  final String value;
  final Color? marker;
  final String? caption;
  final IconData? captionIcon;
  final Color? captionIconColor;

  /// La cifra principal de la pantalla: más grande.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (marker != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: marker,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
              ],
            ),
            const SizedBox(height: 4),
            // Una cifra muy larga se achica en vez de cortarse.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: (hero
                        ? theme.textTheme.displaySmall
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (captionIcon != null) ...[
                    Icon(captionIcon, size: 16, color: captionIconColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
