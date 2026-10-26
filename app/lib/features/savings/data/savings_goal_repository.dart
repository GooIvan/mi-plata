import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/goal_draft.dart';
import '../domain/savings_goal.dart';

/// Acceso a las metas de ahorro en Supabase. El `user_id` lo pone la base de
/// datos. Lo que se lleva ahorrado no está aquí: es el saldo de la cuenta.
class SavingsGoalRepository {
  const SavingsGoalRepository(this._client);

  final SupabaseClient _client;

  Future<List<SavingsGoal>> fetchAll() async {
    final rows = await _client
        .from('savings_goals')
        .select()
        .order('created_at')
        .order('name');
    return rows.map(SavingsGoal.fromJson).toList();
  }

  Future<void> create(GoalDraft draft) async {
    await _client.from('savings_goals').insert(draft.toJson());
  }

  Future<void> update(String id, GoalDraft draft) async {
    await _client.from('savings_goals').update(draft.toJson()).eq('id', id);
  }

  /// Una meta archivada deja libre su cuenta para otra.
  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _client
        .from('savings_goals')
        .update({'is_archived': isArchived})
        .eq('id', id);
  }
}
