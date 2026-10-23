import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/date_format.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/recurring_draft.dart';
import '../domain/recurring_payment.dart';

/// Acceso a los pagos recurrentes en Supabase. El `user_id` lo pone la base de
/// datos.
class RecurringRepository {
  const RecurringRepository(this._client);

  final SupabaseClient _client;

  /// Los que tienen fecha, del más próximo al más lejano; los terminados, al
  /// final.
  Future<List<RecurringPayment>> fetchAll() async {
    final rows = await _client
        .from('recurring_payments')
        .select()
        .order('next_due_date', ascending: true, nullsFirst: false)
        .order('name');
    return rows.map(RecurringPayment.fromJson).toList();
  }

  Future<void> create(RecurringDraft draft) async {
    await _client.from('recurring_payments').insert(draft.toJson());
  }

  Future<void> update(String id, RecurringDraft draft) async {
    await _client
        .from('recurring_payments')
        .update(draft.toJson())
        .eq('id', id);
  }

  Future<void> setPaused(String id, {required bool paused}) async {
    await _client
        .from('recurring_payments')
        .update({'is_paused': paused})
        .eq('id', id);
  }

  /// Los gastos que ya se registraron quedan: solo se pierde su enlace.
  Future<void> delete(String id) async {
    await _client.from('recurring_payments').delete().eq('id', id);
  }

  /// Confirma que se pagó: crea el gasto y pasa al siguiente pago. [amount] es
  /// un decimal exacto en texto.
  Future<void> confirm({
    required String id,
    required String accountId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _client.rpc<dynamic>(
      'confirm_recurring_payment',
      params: {
        'p_id': id,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_date': toDbDate(date),
        'p_description': description,
      },
    );
  }

  /// Omite el pago que toca: pasa al siguiente sin crear ningún movimiento.
  Future<void> skip(String id) async {
    await _client.rpc<dynamic>('skip_recurring_payment', params: {'p_id': id});
  }

  /// Los gastos registrados al confirmar pagos de [id], el más reciente primero.
  Future<List<Transaction>> fetchPayments(String id, {int limit = 24}) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('recurring_payment_id', id)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Transaction.fromJson).toList();
  }
}
