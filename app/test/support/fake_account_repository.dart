import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Account testAccount(
  String name, {
  AccountType type = AccountType.bank,
  double balance = 0,
  bool archived = false,
}) => Account(
  id: 'id-$name',
  name: name,
  type: type,
  currency: 'COP',
  initialBalance: balance,
  currentBalance: balance,
  isArchived: archived,
);

/// Sustituye a [AccountRepository] en las pruebas, con las cuentas en memoria.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository([List<Account> initial = const []])
    : _accounts = [...initial];

  final List<Account> _accounts;

  /// Error que lanzarán todas las operaciones mientras no sea null.
  Object? error;

  final calls = <String>[];

  List<Account> get accounts => List.unmodifiable(_accounts);

  @override
  Future<List<Account>> fetchAll() async {
    calls.add('fetchAll');
    if (error != null) throw error!;
    return [..._accounts]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> create({
    required String name,
    required AccountType type,
    required String initialBalance,
  }) async {
    calls.add('create:$name:${type.name}:$initialBalance');
    if (error != null) throw error!;
    _failIfNameTaken(name);
    _accounts.add(
      testAccount(name, type: type, balance: double.parse(initialBalance)),
    );
  }

  @override
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required String initialBalance,
  }) async {
    calls.add('update:$id:$name:${type.name}:$initialBalance');
    if (error != null) throw error!;
    _failIfNameTaken(name, exceptId: id);
    final index = _accounts.indexWhere((account) => account.id == id);
    final balance = double.parse(initialBalance);
    _accounts[index] = Account(
      id: id,
      name: name,
      type: type,
      currency: 'COP',
      initialBalance: balance,
      currentBalance: balance,
      isArchived: _accounts[index].isArchived,
    );
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) async {
    calls.add('setArchived:$id:$isArchived');
    if (error != null) throw error!;
    final index = _accounts.indexWhere((account) => account.id == id);
    final account = _accounts[index];
    _accounts[index] = Account(
      id: account.id,
      name: account.name,
      type: account.type,
      currency: account.currency,
      initialBalance: account.initialBalance,
      currentBalance: account.currentBalance,
      isArchived: isArchived,
    );
  }

  /// Imita el índice único de nombres entre cuentas activas.
  void _failIfNameTaken(String name, {String? exceptId}) {
    final taken = _accounts.any(
      (account) =>
          !account.isArchived &&
          account.id != exceptId &&
          account.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      throw const PostgrestException(message: 'duplicate key', code: '23505');
    }
  }
}
