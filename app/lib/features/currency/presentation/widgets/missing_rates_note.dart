import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../l10n/l10n.dart';

/// Avisa que el dinero de algunas monedas no se sumó porque no tienen tasa de
/// cambio, y lleva a definirla.
class MissingRatesNote extends StatelessWidget {
  const MissingRatesNote({super.key, required this.currencies, this.onColor});

  final Set<String> currencies;

  /// El color de todo el aviso cuando va sobre un fondo de color (la tarjeta
  /// del dinero total); sin él, usa los colores del tema.
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final codes = (currencies.toList()..sort()).join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.warning_amber_outlined,
            size: 16,
            color: onColor ?? theme.colorScheme.error,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: onColor),
              children: [
                TextSpan(text: '${l10n.currencyMissingRates(codes)} '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.rates),
                    child: Text(
                      l10n.currencyMissingRatesAction,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onColor ?? theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: onColor == null
                            ? null
                            : TextDecoration.underline,
                        decorationColor: onColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
