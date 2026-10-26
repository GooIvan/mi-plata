import '../../../core/format/date_format.dart';
import '../../recurring/domain/recurrence.dart';

/// Los datos de una compra a cuotas: la deuda (lo que se va a pagar en total) y
/// su plan (cuántas cuotas, de cuánto, cada cuánto y desde cuándo).
class InstallmentPlanDraft {
  const InstallmentPlanDraft({
    required this.counterparty,
    required this.amount,
    required this.installments,
    required this.installmentAmount,
    required this.recurrence,
    required this.firstDue,
    required this.accountId,
    this.categoryId,
    required this.startDate,
    this.notes,
  });

  final String counterparty;

  /// El total que se va a pagar (con intereses, si los hay): un decimal exacto
  /// en texto, como lo devuelve `AmountParser`.
  final String amount;
  final int installments;
  final String installmentAmount;
  final Recurrence recurrence;
  final DateTime firstDue;

  /// La cuenta de la que se pagan las cuotas; la deuda es en su moneda.
  final String accountId;
  final String? categoryId;
  final DateTime startDate;
  final String? notes;

  /// Los parámetros de la función `create_installment_debt`.
  Map<String, dynamic> toRpcParams() => {
    'p_counterparty': counterparty,
    'p_amount': amount,
    'p_installments': installments,
    'p_installment_amount': installmentAmount,
    'p_every': recurrence.every,
    'p_unit': recurrence.unit.dbValue,
    'p_first_due': toDbDate(firstDue),
    'p_account_id': accountId,
    'p_category_id': categoryId,
    'p_start_date': toDbDate(startDate),
    'p_notes': notes,
  };
}
