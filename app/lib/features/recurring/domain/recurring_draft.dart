import '../../../core/format/date_format.dart';
import 'recurrence.dart';

/// Los datos de un pago recurrente antes de guardarlo (al crearlo o editarlo).
class RecurringDraft {
  const RecurringDraft({
    required this.name,
    required this.amount,
    required this.accountId,
    this.categoryId,
    required this.recurrence,
    required this.nextDueDate,
    this.endDate,
  });

  final String name;

  /// Decimal exacto en texto, como lo devuelve `AmountParser`.
  final String amount;
  final String accountId;
  final String? categoryId;
  final Recurrence recurrence;
  final DateTime nextDueDate;
  final DateTime? endDate;

  /// Los nulos se envían a propósito: al editar borran lo que ya no aplica
  /// (la categoría o la fecha final). La pausa no va: se cambia aparte.
  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'account_id': accountId,
    'category_id': categoryId,
    'every': recurrence.every,
    'unit': recurrence.unit.dbValue,
    'next_due_date': toDbDate(nextDueDate),
    // El día que se conserva: el del próximo pago que se eligió.
    'anchor_day': nextDueDate.day,
    'end_date': endDate == null ? null : toDbDate(endDate!),
  };
}
