import '../../../core/format/money_format.dart';
import '../../transactions/domain/transaction_validators.dart';
import '../../accounts/domain/amount_parser.dart';

/// Reglas de los formularios de deudas. Los mensajes llegan al usuario.
class DebtValidators {
  const DebtValidators._();

  static const maxCounterpartyLength = 60;
  static const maxNotesLength = 300;

  static String? counterparty(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Escribe el nombre de la persona';
    if (name.length > maxCounterpartyLength) {
      return 'Usa $maxCounterpartyLength caracteres o menos';
    }
    return null;
  }

  static String? notes(String? value) {
    if ((value?.trim().length ?? 0) > maxNotesLength) {
      return 'Usa $maxNotesLength caracteres o menos';
    }
    return null;
  }

  /// El monto de una deuda: positivo, como el de cualquier movimiento.
  static String? amount(String? value) => TransactionValidators.amount(value);

  /// El vencimiento no puede ser antes del inicio (se compara solo el día).
  static String? dueDate(DateTime? due, DateTime start) {
    if (due == null) return null;
    final dueDay = DateTime(due.year, due.month, due.day);
    final startDay = DateTime(start.year, start.month, start.day);
    return dueDay.isBefore(startDay)
        ? 'El vencimiento no puede ser anterior al inicio'
        : null;
  }

  /// Un abono: positivo y sin pasarse de lo que falta por pagar.
  static String? paymentAmount(String? value, {required double remaining}) {
    final error = TransactionValidators.amount(value);
    if (error != null) return error;

    final cents = (double.parse(AmountParser.parse(value)!) * 100).round();
    if (cents > (remaining * 100).round()) {
      return 'No puede superar lo pendiente (${formatMoney(remaining)})';
    }
    return null;
  }
}
