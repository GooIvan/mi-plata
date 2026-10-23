import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/date_format.dart';
import '../domain/debt.dart';
import '../domain/debt_draft.dart';
import '../domain/installment_plan_draft.dart';
import '../domain/debt_payment.dart';

/// Acceso a las deudas en Supabase.
///
/// Crear una deuda y registrar un abono son funciones de Postgres
/// (`create_debt`, `register_debt_payment`) que crean el movimiento y la deuda
/// a la vez: o pasa todo o no pasa nada.
class DebtRepository {
  const DebtRepository(this._client);

  final SupabaseClient _client;

  Future<List<Debt>> fetchAll() async {
    final rows = await _client
        .from('v_debt_balances')
        .select()
        .order('start_date', ascending: false);
    return rows.map(Debt.fromJson).toList();
  }

  /// Los abonos de una deuda, el más reciente primero.
  Future<List<DebtPayment>> fetchPayments(String debtId) async {
    final rows = await _client
        .from('v_debt_payments')
        .select()
        .eq('debt_id', debtId)
        .order('transaction_date', ascending: false);
    return rows.map(DebtPayment.fromJson).toList();
  }

  Future<void> create(DebtDraft draft) async {
    await _client.rpc<dynamic>('create_debt', params: draft.toRpcParams());
  }

  /// Crea una compra a cuotas: la deuda y su plan de pagos, todo o nada.
  Future<void> createWithInstallments(InstallmentPlanDraft draft) async {
    await _client.rpc<dynamic>(
      'create_installment_debt',
      params: draft.toRpcParams(),
    );
  }

  /// El monto, la persona, el vencimiento y las notas. El sentido (debo / me
  /// deben) y el inicio no se editan.
  Future<void> update(
    String id, {
    required String counterparty,
    required String amount,
    DateTime? dueDate,
    String? notes,
  }) async {
    await _client
        .from('debts')
        .update({
          'counterparty': counterparty,
          'amount': amount,
          'due_date': dueDate == null ? null : toDbDate(dueDate),
          'notes': notes,
        })
        .eq('id', id);
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _client.from('debts').update({'is_archived': isArchived}).eq('id', id);
  }

  Future<void> registerPayment({
    required String debtId,
    required String accountId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _client.rpc<dynamic>(
      'register_debt_payment',
      params: {
        'p_debt_id': debtId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_date': toDbDate(date),
        'p_description': description,
      },
    );
  }
}
