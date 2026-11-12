import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import '../domain/account_type.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(supabaseClientProvider)),
);

final accountsProvider =
    AsyncNotifierProvider.autoDispose<AccountsNotifier, List<Account>>(
      AccountsNotifier.new,
    );

/// Lista de cuentas con su saldo. Las operaciones lanzan el error si fallan,
/// para que quien las llama (formulario, menú) pueda avisar al usuario.
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  AccountRepository get _repository => ref.read(accountRepositoryProvider);

  @override
  Future<List<Account>> build() {
    // Los saldos dependen de los movimientos: se recarga cuando cambian.
    ref.watch(ledgerRevisionProvider);
    return _repository.fetchAll();
  }

  Future<void> create({
    required String name,
    required AccountType type,
    required String initialBalance,
    required String currency,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    await _repository.create(
      name: name,
      type: type,
      initialBalance: initialBalance,
      currency: currency,
      creditLimit: creditLimit,
      statementDay: statementDay,
      paymentDay: paymentDay,
    );
    ref.invalidateSelf();
  }

  Future<void> edit({
    required String id,
    required String name,
    required AccountType type,
    required String initialBalance,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    await _repository.update(
      id: id,
      name: name,
      type: type,
      initialBalance: initialBalance,
      creditLimit: creditLimit,
      statementDay: statementDay,
      paymentDay: paymentDay,
    );
    ref.invalidateSelf();
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _repository.setArchived(id, isArchived: isArchived);
    ref.invalidateSelf();
  }
}
