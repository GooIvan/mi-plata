import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import 'amount_parser.dart';

/// Reglas de los campos de una compra diferida en cuotas. Los mensajes llegan
/// al usuario.
class CardInstallmentValidators {
  const CardInstallmentValidators._();

  static const minInstallments = 2;
  static const maxInstallments = 60;

  /// El número de cuotas, de 2 a 60.
  static String? count(AppLocalizations l10n, String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    return count != null && count >= minInstallments && count <= maxInstallments
        ? null
        : l10n.cardInstallmentsCountInvalid;
  }

  /// El valor de cada cuota: vacío vale (no hay intereses); si se escribe, un
  /// monto mayor que cero.
  static String? amount(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = AmountParser.parse(value, Formats(l10n));
    if (parsed == null) return l10n.commonInvalidAmount;
    return double.parse(parsed) > 0 ? null : l10n.cardInstallmentsAmountInvalid;
  }
}
