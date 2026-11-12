import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account.dart';
import '../domain/account_type.dart';

/// Acceso a las cuentas en Supabase. Lee los saldos de `v_account_balances`
/// y escribe en `accounts`; el `user_id` lo pone la base de datos.
class AccountRepository {
  const AccountRepository(this._client);

  final SupabaseClient _client;

  Future<List<Account>> fetchAll() async {
    final rows = await _client.from('v_account_balances').select().order('name');
    return rows.map(Account.fromJson).toList();
  }

  /// [initialBalance] es un decimal en texto, como lo devuelve `AmountParser`.
  /// La moneda de una cuenta se elige al crearla y no se cambia después.
  ///
  /// [creditLimit] (decimal en texto), [statementDay] y [paymentDay] solo valen
  /// en una tarjeta; los dos días van juntos o ninguno.
  Future<void> create({
    required String name,
    required AccountType type,
    required String initialBalance,
    required String currency,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    await _client.from('accounts').insert({
      'name': name,
      'type': type.dbValue,
      'initial_balance': initialBalance,
      'currency': currency,
      'credit_limit': creditLimit,
      'statement_day': statementDay,
      'payment_day': paymentDay,
    });
  }

  /// Los datos de la tarjeta se envían siempre, aunque sean nulos: al pasar una
  /// cuenta a otro tipo, o al borrar el cupo, tienen que quedar vacíos.
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required String initialBalance,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    await _client
        .from('accounts')
        .update({
          'name': name,
          'type': type.dbValue,
          'initial_balance': initialBalance,
          'credit_limit': creditLimit,
          'statement_day': statementDay,
          'payment_day': paymentDay,
        })
        .eq('id', id);
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _client
        .from('accounts')
        .update({'is_archived': isArchived})
        .eq('id', id);
  }
}
