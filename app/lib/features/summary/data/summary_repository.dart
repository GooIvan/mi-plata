import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/balance_history.dart';
import '../domain/monthly_total.dart';

/// Lee los totales mensuales de `v_monthly_totals`.
class SummaryRepository {
  const SummaryRepository(this._client);

  final SupabaseClient _client;

  /// Los totales de los meses entre [from] y [to], ambos incluidos.
  /// Las filas son pocas (meses × tipos × categorías), muy por debajo del
  /// límite de filas de la API.
  Future<List<MonthlyTotal>> fetchMonthlyTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('v_monthly_totals')
        .select()
        .gte('month', _day(from))
        .lte('month', _day(to));
    return rows.map(MonthlyTotal.fromJson).toList();
  }

  /// Lo que entró y salió de cada cuenta en cada mes, de todo el historial.
  ///
  /// Son pocas filas (meses × cuentas): unas 120 por año con diez cuentas.
  Future<List<AccountFlow>> fetchAccountFlows() async {
    final rows = await _client.from('v_monthly_account_flows').select();
    return rows.map(AccountFlow.fromJson).toList();
  }

  static String _day(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-01';
  }
}
