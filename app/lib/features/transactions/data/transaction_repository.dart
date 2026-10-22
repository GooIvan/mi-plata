import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/date_format.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';
import '../domain/transaction_filter.dart';

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

  /// Una página de movimientos que cumplen [filter], los más recientes primero.
  ///
  /// El orden incluye el `id` como desempate, para que dos páginas seguidas
  /// nunca repitan ni se salten un movimiento de la misma fecha.
  Future<List<Transaction>> fetchPage({
    required TransactionFilter filter,
    required int offset,
    int limit = pageSize,
  }) async {
    var query = _client.from('transactions').select();

    final text = filter.text;
    if (text != null) {
      query = query.ilike('description', '%${_escapeLike(text)}%');
    }
    if (filter.type != null) {
      query = query.eq('type', filter.type!.dbValue);
    }
    final account = filter.accountId;
    if (account != null) {
      query = query.or('account_id.eq.$account,destination_account_id.eq.$account');
    }
    if (filter.uncategorized) {
      query = query.isFilter('category_id', null);
    } else if (filter.categoryId != null) {
      query = query.eq('category_id', filter.categoryId!);
    }
    if (filter.from != null) {
      query = query.gte('transaction_date', toDbDate(filter.from!));
    }
    if (filter.to != null) {
      query = query.lte('transaction_date', toDbDate(filter.to!));
    }

    final rows = await query
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map(Transaction.fromJson).toList();
  }

  /// Cuántos movimientos trae cada página.
  static const pageSize = 40;

  /// Para buscar un texto literal: `%`, `_` y `\` tienen significado en LIKE.
  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

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
