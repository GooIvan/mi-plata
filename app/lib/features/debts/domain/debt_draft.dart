import '../../../core/format/date_format.dart';
import 'debt_direction.dart';

/// Los datos de una deuda nueva. Con [accountId] se registra además el dinero
/// en esa cuenta: entra si me prestaron, sale si presté.
class DebtDraft {
  const DebtDraft({
    required this.direction,
    required this.counterparty,
    required this.amount,
    required this.startDate,
    this.dueDate,
    this.notes,
    this.accountId,
    this.description,
    this.currency,
  });

  final DebtDirection direction;
  final String counterparty;

  /// Decimal exacto en texto, como lo devuelve `AmountParser`.
  final String amount;
  final DateTime startDate;
  final DateTime? dueDate;
  final String? notes;
  final String? accountId;

  /// Cómo se llamará el movimiento del dinero (si se registra en una cuenta):
  /// lo escribe la app en el idioma del usuario. Sin él, la base usa el suyo.
  final String? description;

  /// La moneda de la deuda cuando no se registra en una cuenta (con cuenta es
  /// la de la cuenta). Null deja que la base use la moneda base del usuario.
  final String? currency;

  /// Los parámetros de la función `create_debt`.
  Map<String, dynamic> toRpcParams() => {
    'p_direction': direction.dbValue,
    'p_counterparty': counterparty,
    'p_amount': amount,
    'p_start_date': toDbDate(startDate),
    'p_due_date': dueDate == null ? null : toDbDate(dueDate!),
    'p_notes': notes,
    'p_account_id': accountId,
    'p_description': description,
    'p_currency': currency,
  };
}
