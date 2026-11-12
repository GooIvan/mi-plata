import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Account testAccount(
  String name, {
  AccountType type = AccountType.bank,
  double balance = 0,
  bool archived = false,
  String currency = 'COP',
  double? creditLimit,
  int? statementDay,
  int? paymentDay,
}) => Account(
  id: 'id-$name',
  name: name,
  type: type,
  currency: currency,
  initialBalance: balance,
  currentBalance: balance,
  isArchived: archived,
  creditLimit: creditLimit,
  statementDay: statementDay,
  paymentDay: paymentDay,
);

/// Lo que se anota en [FakeAccountRepository.calls] sobre los datos de una
/// tarjeta: nada si no hay, para que las pruebas de siempre no cambien.
String _termsNote({String? creditLimit, int? statementDay, int? paymentDay}) =>
    [
      if (creditLimit != null) ':limit=$creditLimit',
      if (statementDay != null) ':statement=$statementDay',
      if (paymentDay != null) ':payment=$paymentDay',
    ].join();

/// Sustituye a [AccountRepository] en las pruebas, con las cuentas en memoria.
///
/// Si recibe la lista de [transactions] (compartida por referencia), el saldo
/// de cada cuenta se calcula como lo hace la vista `v_account_balances`.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository([
    List<Account> initial = const [],
    this.transactions = const [],
  ]) : _accounts = [...initial];

  final List<Account> _accounts;
  final List<Transaction> transactions;

  /// Error que lanzarán todas las operaciones mientras no sea null.
  Object? error;

  final calls = <String>[];

  List<Account> get accounts => List.unmodifiable(_accounts);

  double _flow(String accountId) {
    var total = 0.0;
    for (final transaction in transactions) {
      if (transaction.accountId == accountId) {
        total += transaction.type == TransactionType.income
            ? transaction.amount
            : -transaction.amount;
      }
      if (transaction.type == TransactionType.transfer &&
          transaction.destinationAccountId == accountId) {
        total += transaction.destinationAmount ?? transaction.amount;
      }
    }
    return total;
  }

  @override
  Future<List<Account>> fetchAll() async {
    calls.add('fetchAll');
    if (error != null) throw error!;
    return [
      for (final account in _accounts)
        _copy(
          account,
          currentBalance: account.initialBalance + _flow(account.id),
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> create({
    required String name,
    required AccountType type,
    required String initialBalance,
    required String currency,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    // La moneda solo se anota cuando no es el peso: así las pruebas de siempre
    // siguen comparando 'create:Nombre:tipo:saldo'.
    calls.add(
      'create:$name:${type.name}:$initialBalance'
      '${currency == 'COP' ? '' : ':$currency'}'
      '${_termsNote(creditLimit: creditLimit, statementDay: statementDay, paymentDay: paymentDay)}',
    );
    if (error != null) throw error!;
    _failIfNameTaken(name);
    _accounts.add(
      testAccount(
        name,
        type: type,
        balance: double.parse(initialBalance),
        currency: currency,
        creditLimit: creditLimit == null ? null : double.parse(creditLimit),
        statementDay: statementDay,
        paymentDay: paymentDay,
      ),
    );
  }

  @override
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required String initialBalance,
    String? creditLimit,
    int? statementDay,
    int? paymentDay,
  }) async {
    calls.add(
      'update:$id:$name:${type.name}:$initialBalance'
      '${_termsNote(creditLimit: creditLimit, statementDay: statementDay, paymentDay: paymentDay)}',
    );
    if (error != null) throw error!;
    _failIfNameTaken(name, exceptId: id);
    final index = _accounts.indexWhere((account) => account.id == id);
    final balance = double.parse(initialBalance);
    _accounts[index] = Account(
      id: id,
      name: name,
      type: type,
      currency: _accounts[index].currency,
      initialBalance: balance,
      currentBalance: balance,
      isArchived: _accounts[index].isArchived,
      creditLimit: creditLimit == null ? null : double.parse(creditLimit),
      statementDay: statementDay,
      paymentDay: paymentDay,
    );
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) async {
    calls.add('setArchived:$id:$isArchived');
    if (error != null) throw error!;
    final index = _accounts.indexWhere((account) => account.id == id);
    _accounts[index] = _copy(_accounts[index], isArchived: isArchived);
  }

  Account _copy(Account account, {double? currentBalance, bool? isArchived}) =>
      Account(
        id: account.id,
        name: account.name,
        type: account.type,
        currency: account.currency,
        initialBalance: account.initialBalance,
        currentBalance: currentBalance ?? account.currentBalance,
        isArchived: isArchived ?? account.isArchived,
        creditLimit: account.creditLimit,
        statementDay: account.statementDay,
        paymentDay: account.paymentDay,
      );

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
