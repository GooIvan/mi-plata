import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import 'fake_account_repository.dart';

Category testCategory(
  String name,
  CategoryType type, {
  bool archived = false,
}) => Category(id: 'cat-$name', name: name, type: type, isArchived: archived);

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
  FakeCategoryRepository([List<Category> initial = const []])
    : _categories = [...initial];

  final List<Category> _categories;

  /// Error que lanzarán todas las operaciones mientras no sea null.
  Object? error;

  final calls = <String>[];

  List<Category> get categories => List.unmodifiable(_categories);

  @override
  Future<List<Category>> fetchAll() async {
    calls.add('fetchAll');
    if (error != null) throw error!;
    return [..._categories]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> create({required String name, required CategoryType type}) async {
    calls.add('create:$name:${type.name}');
    if (error != null) throw error!;
    _failIfNameTaken(name, type);
    _categories.add(testCategory(name, type));
  }

  @override
  Future<void> rename(String id, String name) async {
    calls.add('rename:$id:$name');
    if (error != null) throw error!;
    final index = _categories.indexWhere((category) => category.id == id);
    final category = _categories[index];
    _failIfNameTaken(name, category.type, exceptId: id);
    _categories[index] = Category(
      id: id,
      name: name,
      type: category.type,
      isArchived: category.isArchived,
    );
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) async {
    calls.add('setArchived:$id:$isArchived');
    if (error != null) throw error!;
    final index = _categories.indexWhere((category) => category.id == id);
    final category = _categories[index];
    _failIfNameTaken(category.name, category.type, exceptId: id, enforce: !isArchived);
    _categories[index] = Category(
      id: id,
      name: category.name,
      type: category.type,
      isArchived: isArchived,
    );
  }

  /// Imita el índice único: nombre repetido entre activas del mismo tipo.
  void _failIfNameTaken(
    String name,
    CategoryType type, {
    String? exceptId,
    bool enforce = true,
  }) {
    if (!enforce) return;
    final taken = _categories.any(
      (category) =>
          !category.isArchived &&
          category.type == type &&
          category.id != exceptId &&
          category.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      throw const PostgrestException(message: 'duplicate key', code: '23505');
    }
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
