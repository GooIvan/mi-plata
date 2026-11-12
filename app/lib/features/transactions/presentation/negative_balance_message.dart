import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/credit_limit_check.dart';
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

/// "Visa quedaría $200.000 por encima de su cupo.", una línea por tarjeta.
String creditLimitMessage(
  AppLocalizations l10n,
  List<CreditLimitExceeded> warnings,
) {
  final formats = Formats(l10n);
  return warnings
      .map(
        (warning) => l10n.creditLimitMessage(
          warning.account.name,
          formats.money(
            warning.overCents / 100,
            currency: warning.account.currency,
          ),
        ),
      )
      .join('\n');
}
