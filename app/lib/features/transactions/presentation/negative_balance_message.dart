import '../../../core/format/money_format.dart';
import '../domain/negative_balance_check.dart';

/// "Nequi quedará en -$2.000.", una línea por cuenta afectada.
String negativeBalanceMessage(List<NegativeBalance> warnings) => warnings
    .map(
      (warning) =>
          '${warning.account.name} quedará en '
          '${formatMoney(warning.balance, currency: warning.account.currency)}.',
    )
    .join('\n');
