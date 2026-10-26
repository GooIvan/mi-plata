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
}
