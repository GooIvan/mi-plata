import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';

/// Acceso a los movimientos en Supabase. El `user_id` lo pone la base de datos.
class TransactionRepository {
  const TransactionRepository(this._client);

  final SupabaseClient _client;

  /// Los movimientos más recientes primero.
  Future<List<Transaction>> fetchRecent({int limit = 200}) async {
    final rows = await _client
        .from('transactions')
        .select()
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Transaction.fromJson).toList();
  }

  Future<void> create(TransactionDraft draft) async {
    await _client.from('transactions').insert(draft.toJson());
  }

  Future<void> update(String id, TransactionDraft draft) async {
    await _client.from('transactions').update(draft.toJson()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
