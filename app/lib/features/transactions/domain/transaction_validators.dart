import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';

/// Reglas del formulario de movimientos. Los mensajes llegan al usuario.
class TransactionValidators {
  const TransactionValidators._();

  static const maxDescriptionLength = 200;

  static String? amount(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.transactionsAmountRequired;
    }

    final parsed = AmountParser.parse(value, Formats(l10n));
    if (parsed == null) return l10n.commonInvalidAmount;
    if (parsed.startsWith('-')) return l10n.transactionsAmountNegative;
    if (double.parse(parsed) == 0) return l10n.transactionsAmountZero;
    return null;
  }

  static String? description(AppLocalizations l10n, String? value) {
    if ((value?.trim().length ?? 0) > maxDescriptionLength) {
      return l10n.commonNameTooLong(maxDescriptionLength);
    }
    return null;
  }
}
