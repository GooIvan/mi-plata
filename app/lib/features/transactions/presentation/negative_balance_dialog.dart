import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../domain/credit_limit_check.dart';
import '../domain/negative_balance_check.dart';
import 'negative_balance_message.dart';

/// Avisa que el cambio dejaría cuentas en negativo, o tarjetas por encima de su
/// cupo (los dos avisos van juntos en un solo diálogo), y pregunta si
/// continuar. Devuelve `true` si el usuario quiere seguir de todos modos.
Future<bool> confirmNegativeBalance(
  BuildContext context,
  List<NegativeBalance> warnings, {
  List<CreditLimitExceeded> overLimit = const [],
  required String title,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        '${[
          if (warnings.isNotEmpty) negativeBalanceMessage(context.l10n, warnings),
          if (overLimit.isNotEmpty) creditLimitMessage(context.l10n, overLimit),
        ].join('\n')}\n\n'
        '${context.l10n.negativeBalanceAdvice}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.negativeBalanceFix),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
