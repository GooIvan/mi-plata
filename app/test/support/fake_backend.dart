import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import 'fake_account_repository.dart';

Category testCategory(String name, CategoryType type) =>
    Category(id: 'cat-$name', name: name, type: type);

Transaction testTransaction(
  String id, {
  required TransactionType type,
  required String accountId,
  String? destinationAccountId,
  String? categoryId,
  required double amount,
  required DateTime date,
  String? description,
}) => Transaction(
  id: id,
  type: type,
  accountId: accountId,
  destinationAccountId: destinationAccountId,
  categoryId: categoryId,
  amount: amount,
  date: date,
  description: description,
);

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([this.categories = const []]);

  final List<Category> categories;
  Object? error;

  @override
  Future<List<Category>> fetchActive() async {
    if (error != null) throw error!;
    return [...categories]..sort((a, b) => a.name.compareTo(b.name));
  }
}

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository(this.transactions);

  /// Compartida con [FakeAccountRepository] para que cambien los saldos.
  final List<Transaction> transactions;

  Object? error;

  final created = <TransactionDraft>[];
  final updated = <String, TransactionDraft>{};
  final deleted = <String>[];
  var _nextId = 1;

  @override
  Future<List<Transaction>> fetchRecent({int limit = 200}) async {
    if (error != null) throw error!;
    final indexed = transactions.asMap().entries.toList()
      ..sort((a, b) {
        final byDate = b.value.date.compareTo(a.value.date);
        return byDate != 0 ? byDate : b.key.compareTo(a.key);
      });
    return [for (final entry in indexed.take(limit)) entry.value];
  }

  @override
  Future<void> create(TransactionDraft draft) async {
    if (error != null) throw error!;
    created.add(draft);
    transactions.add(_fromDraft('new-${_nextId++}', draft));
  }

  @override
  Future<void> update(String id, TransactionDraft draft) async {
    if (error != null) throw error!;
    updated[id] = draft;
    final index = transactions.indexWhere((t) => t.id == id);
    transactions[index] = _fromDraft(id, draft);
  }

  @override
  Future<void> delete(String id) async {
    if (error != null) throw error!;
    deleted.add(id);
    transactions.removeWhere((t) => t.id == id);
  }

  Transaction _fromDraft(String id, TransactionDraft draft) => Transaction(
    id: id,
    type: draft.type,
    accountId: draft.accountId,
    destinationAccountId: draft.destinationAccountId,
    categoryId: draft.categoryId,
    amount: double.parse(draft.amount),
    date: draft.date,
    description: draft.description,
  );
}

/// Cuentas, categorías y movimientos enlazados, como la base de datos real.
class FakeBackend {
  factory FakeBackend({
    List<Account> accounts = const [],
    List<Category> categories = const [],
    List<Transaction> transactions = const [],
  }) {
    final shared = [...transactions];
    return FakeBackend._(
      FakeAccountRepository(accounts, shared),
      FakeTransactionRepository(shared),
      FakeCategoryRepository(categories),
    );
  }

  FakeBackend._(this.accounts, this.transactions, this.categories);

  final FakeAccountRepository accounts;
  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
}
