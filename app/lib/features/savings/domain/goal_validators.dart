import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';

/// Reglas del formulario de metas. Los mensajes llegan al usuario.
class GoalValidators {
  const GoalValidators._();

  static const maxNameLength = 60;

  static String? name(AppLocalizations l10n, String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return l10n.goalsNameRequired;
    if (name.length > maxNameLength) {
      return l10n.commonNameTooLong(maxNameLength);
    }
    return null;
  }

  /// El monto de la meta: un número mayor que cero.
  static String? target(AppLocalizations l10n, String? value) {
    final amount = AmountParser.parse(value, Formats(l10n));
    if (amount == null) return l10n.commonInvalidAmount;
    if (double.parse(amount) <= 0) return l10n.goalsTargetPositive;
    return null;
  }
}
