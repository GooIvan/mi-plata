import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/date_format.dart';
import '../domain/budget_rule.dart';

/// Acceso a los presupuestos en Supabase. El `user_id` lo pone la base de datos.
class BudgetRepository {
  const BudgetRepository(this._client);

  final SupabaseClient _client;

  /// Todas las reglas de presupuesto del usuario. Son pocas: una por cambio.
  Future<List<BudgetRule>> fetchAll() async {
    final rows = await _client.from('budgets').select();
    return rows.map(BudgetRule.fromJson).toList();
  }

  /// Define el presupuesto de [categoryId] desde [month] en adelante. Si ya
  /// había uno para ese mes, lo reemplaza. [amount] es un decimal en texto; con
  /// "0" la categoría queda sin presupuesto desde ese mes.
  Future<void> set({
    required String categoryId,
    required DateTime month,
    required String amount,
  }) async {
    await _client.from('budgets').upsert({
      'category_id': categoryId,
      'effective_month': toDbDate(DateTime(month.year, month.month)),
      'amount': amount,
    }, onConflict: 'category_id,effective_month');
  }
}
