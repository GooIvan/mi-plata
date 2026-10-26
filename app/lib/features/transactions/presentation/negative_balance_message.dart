import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/negative_balance_check.dart';

/// "Nequi quedará en -$2.000.", una línea por cuenta afectada.
String negativeBalanceMessage(
  AppLocalizations l10n,
  List<NegativeBalance> warnings,
) {
  final formats = Formats(l10n);
  return warnings
      .map(
        (warning) => l10n.negativeBalanceMessage(
          warning.account.name,
          formats.money(warning.balance, currency: warning.account.currency),
        ),
      )
      .join('\n');
}
