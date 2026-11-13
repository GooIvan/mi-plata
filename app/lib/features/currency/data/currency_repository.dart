import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/currency.dart';
import '../domain/exchange_rate.dart';

/// Acceso a la moneda base y las tasas de cambio en Supabase. El `user_id` lo
/// pone la base de datos.
class CurrencyRepository {
  const CurrencyRepository(this._client);

  final SupabaseClient _client;

  /// La moneda base; si el usuario nunca la eligió, el peso colombiano.
  Future<String> fetchBaseCurrency() async {
    final row = await _client
        .from('user_settings')
        .select('base_currency')
        .maybeSingle();
    return (row?['base_currency'] as String?) ?? defaultCurrency;
  }

  Future<List<ExchangeRate>> fetchRates() async {
    final rows = await _client
        .from('exchange_rates')
        .select()
        .order('currency');
    return rows.map(ExchangeRate.fromJson).toList();
  }

  /// Define cuánto vale 1 [currency] en la moneda base. [rate] es un decimal
  /// exacto en texto.
  Future<void> setRate(String currency, String rate) async {
    await _client.rpc<dynamic>(
      'set_exchange_rate',
      params: {'p_currency': currency, 'p_rate': rate},
    );
  }

  /// Guarda las tasas que trajo el servicio ([rates]: moneda -> decimal exacto en
  /// texto). Crea las que faltan y actualiza solo las automáticas; las manuales
  /// no se tocan. Devuelve cuántas escribió.
  Future<int> setAutomaticRates(Map<String, String> rates) async {
    final written = await _client.rpc<dynamic>(
      'set_automatic_rates',
      params: {'p_rates': rates},
    );
    return (written as num?)?.toInt() ?? 0;
  }

  /// Hace automática la tasa de [currency]: deja de ser manual y la próxima
  /// actualización la reemplaza.
  Future<void> useAutomaticRate(String currency) async {
    await _client
        .from('exchange_rates')
        .update({'is_manual': false})
        .eq('currency', currency);
  }

  Future<void> deleteRate(String currency) async {
    await _client.from('exchange_rates').delete().eq('currency', currency);
  }

  /// Cambia la moneda base. [rate] es cuánto vale 1 [currency] en la base de
  /// ahora; hace falta si hay tasas o presupuestos que convertir y la moneda
  /// nueva no tiene tasa.
  Future<void> setBaseCurrency(String currency, {String? rate}) async {
    await _client.rpc<dynamic>(
      'set_base_currency',
      params: {'p_currency': currency, 'p_rate': rate},
    );
  }
}
