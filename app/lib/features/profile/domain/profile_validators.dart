import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';

/// Reglas de los datos personales (en el registro y en el perfil). Los mensajes
/// llegan al usuario.
class ProfileValidators {
  const ProfileValidators._();

  static const maxNameLength = 60;
  static const maxProfessionLength = 80;

  /// La fecha de nacimiento más antigua que se acepta.
  static final earliestBirthDate = DateTime(1900);

  /// Nombres y apellidos: obligatorios, con un máximo.
  static String? firstName(AppLocalizations l10n, String? value) =>
      _name(l10n, value, l10n.profileFirstNameRequired);

  static String? lastName(AppLocalizations l10n, String? value) =>
      _name(l10n, value, l10n.profileLastNameRequired);

  static String? _name(AppLocalizations l10n, String? value, String required) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return required;
    if (name.length > maxNameLength) {
      return l10n.commonNameTooLong(maxNameLength);
    }
    return null;
  }

  /// La profesión: puede ir vacía; si se escribe, con un máximo.
  static String? profession(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxProfessionLength) {
      return l10n.commonNameTooLong(maxProfessionLength);
    }
    return null;
  }

  /// La fecha de nacimiento: puede faltar; si se da, no puede ser futura ni
  /// anterior a 1900. [today] es para las pruebas.
  static String? birthDate(
    AppLocalizations l10n,
    DateTime? value, {
    DateTime? today,
  }) {
    if (value == null) return null;
    final now = today ?? DateTime.now();
    final day = DateTime(value.year, value.month, value.day);
    final current = DateTime(now.year, now.month, now.day);
    if (day.isAfter(current) || day.isBefore(earliestBirthDate)) {
      return l10n.profileBirthDateInvalid;
    }
    return null;
  }

  /// El ingreso mensual: puede ir vacío; si se escribe, un monto mayor que cero.
  static String? monthlyIncome(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = AmountParser.parse(value, Formats(l10n));
    if (parsed == null) return l10n.commonInvalidAmount;
    return double.parse(parsed) > 0 ? null : l10n.profileIncomeInvalid;
  }
}
