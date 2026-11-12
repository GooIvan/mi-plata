import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import 'amount_parser.dart';

/// Reglas del formulario de cuentas. Los mensajes llegan al usuario.
class AccountValidators {
  const AccountValidators._();

  static const maxNameLength = 40;

  static String? name(AppLocalizations l10n, String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return l10n.accountsNameRequired;
    if (name.length > maxNameLength) {
      return l10n.commonNameTooLong(maxNameLength);
    }
    return null;
  }

  static String? initialBalance(AppLocalizations l10n, String? value) {
    if (AmountParser.parse(value, Formats(l10n)) == null) {
      return l10n.commonInvalidAmount;
    }
    return null;
  }

  /// El cupo de una tarjeta: vacío vale (no se da); si se escribe, un monto
  /// mayor que cero.
  static String? creditLimit(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = AmountParser.parse(value, Formats(l10n));
    if (parsed == null) return l10n.commonInvalidAmount;
    return double.parse(parsed) > 0 ? null : l10n.accountsCardLimitInvalid;
  }

  /// Un día del mes: vacío vale; si se escribe, un entero del 1 al 31.
  static String? cardDay(AppLocalizations l10n, String? value) {
    final day = parseDay(value);
    if (value == null || value.trim().isEmpty) return null;
    return day == null ? l10n.accountsCardDayInvalid : null;
  }

  /// Los dos días van juntos: o se dan los dos o ninguno. Se evalúa en el
  /// segundo campo, con lo que haya escrito en el primero.
  static String? cardDaysTogether(
    AppLocalizations l10n,
    String? statement,
    String? payment,
  ) {
    final hasStatement = statement != null && statement.trim().isNotEmpty;
    final hasPayment = payment != null && payment.trim().isNotEmpty;
    return hasStatement == hasPayment ? null : l10n.accountsCardDaysTogether;
  }

  /// El día del mes que escribió el usuario; null si está vacío o no vale.
  static int? parseDay(String? value) {
    final day = int.tryParse(value?.trim() ?? '');
    return day != null && day >= 1 && day <= 31 ? day : null;
  }
}
