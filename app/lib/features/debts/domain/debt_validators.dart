import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../transactions/domain/transaction_validators.dart';

/// Reglas de los formularios de deudas. Los mensajes llegan al usuario.
class DebtValidators {
  const DebtValidators._();

  static const maxCounterpartyLength = 60;
  static const maxNotesLength = 300;

  static String? counterparty(AppLocalizations l10n, String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return l10n.debtsCounterpartyRequired;
    if (name.length > maxCounterpartyLength) {
      return l10n.commonNameTooLong(maxCounterpartyLength);
    }
    return null;
  }

  static String? notes(AppLocalizations l10n, String? value) {
    if ((value?.trim().length ?? 0) > maxNotesLength) {
      return l10n.commonNameTooLong(maxNotesLength);
    }
    return null;
  }

  /// El monto de una deuda: positivo, como el de cualquier movimiento.
  static String? amount(AppLocalizations l10n, String? value) =>
      TransactionValidators.amount(l10n, value);

  /// El vencimiento no puede ser antes del inicio (se compara solo el día).
  static String? dueDate(
    AppLocalizations l10n,
    DateTime? due,
    DateTime start,
  ) {
    if (due == null) return null;
    final dueDay = DateTime(due.year, due.month, due.day);
    final startDay = DateTime(start.year, start.month, start.day);
    return dueDay.isBefore(startDay) ? l10n.debtsDueBeforeStart : null;
  }

  /// Un abono: positivo y sin pasarse de lo que falta por pagar.
  static String? paymentAmount(
    AppLocalizations l10n,
    String? value, {
    required double remaining,
  }) {
    final error = TransactionValidators.amount(l10n, value);
    if (error != null) return error;

    final formats = Formats(l10n);
    final cents = (double.parse(AmountParser.parse(value, formats)!) * 100)
        .round();
    if (cents > (remaining * 100).round()) {
      return l10n.debtsPaymentExceeds(formats.money(remaining));
    }
    return null;
  }
}
