import '../../../l10n/l10n.dart';

/// Reglas del formulario de pagos recurrentes. Los mensajes llegan al usuario.
class RecurringValidators {
  const RecurringValidators._();

  static const maxNameLength = 60;

  static String? name(AppLocalizations l10n, String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return l10n.recurringNameRequired;
    if (name.length > maxNameLength) {
      return l10n.commonNameTooLong(maxNameLength);
    }
    return null;
  }

  /// La fecha final no puede ser antes del próximo pago (se compara el día).
  static String? endDate(AppLocalizations l10n, DateTime? end, DateTime next) {
    if (end == null) return null;
    final endDay = DateTime(end.year, end.month, end.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    return endDay.isBefore(nextDay) ? l10n.recurringEndBeforeNext : null;
  }
}
