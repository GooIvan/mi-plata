import 'dart:async';

import 'package:mi_plata/features/budgets/data/budget_repository.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/debts/data/debt_repository.dart';
import 'package:mi_plata/features/debts/domain/debt.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/debts/domain/debt_draft.dart';
import 'package:mi_plata/features/debts/domain/debt_payment.dart';
import 'package:mi_plata/features/summary/data/summary_repository.dart';
import 'package:mi_plata/features/summary/domain/balance_history.dart';
import 'package:mi_plata/features/summary/domain/monthly_total.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_filter.dart';
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

  /// Las páginas que se han pedido, para comprobar cuántas y con qué filtro.
  final pageRequests = <({TransactionFilter filter, int offset, int limit})>[];

  /// Si es true, las páginas posteriores a la primera fallan (la primera no).
  bool failLaterPages = false;

  bool _matches(Transaction t, TransactionFilter filter) {
    final text = filter.text?.toLowerCase();
    if (text != null && !(t.description ?? '').toLowerCase().contains(text)) {
      return false;
    }
    if (filter.type != null && t.type != filter.type) return false;
    if (filter.accountId != null &&
        t.accountId != filter.accountId &&
        t.destinationAccountId != filter.accountId) {
      return false;
    }
    if (filter.uncategorized && t.categoryId != null) return false;
    if (filter.categoryId != null && t.categoryId != filter.categoryId) {
      return false;
    }
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (filter.from != null && day.isBefore(filter.from!)) return false;
    if (filter.to != null && day.isAfter(filter.to!)) return false;
    return true;
  }

  @override
  Future<List<Transaction>> fetchPage({
    required TransactionFilter filter,
    required int offset,
    int limit = TransactionRepository.pageSize,
  }) async {
    pageRequests.add((filter: filter, offset: offset, limit: limit));
    if (error != null) throw error!;
    if (failLaterPages && offset > 0) {
      throw const PostgrestException(message: 'boom', code: '500');
    }

    final indexed = transactions.asMap().entries
        .where((entry) => _matches(entry.value, filter))
        .toList()
      ..sort((a, b) {
        final byDate = b.value.date.compareTo(a.value.date);
        return byDate != 0 ? byDate : b.key.compareTo(a.key);
      });
    return [for (final entry in indexed.skip(offset).take(limit)) entry.value];
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

/// Imita la vista `v_monthly_totals`: agrupa por mes, tipo y categoría, y deja
/// fuera las transferencias.
class FakeSummaryRepository implements SummaryRepository {
  FakeSummaryRepository(this.transactions);

  final List<Transaction> transactions;
  Object? error;
  final requests = <({DateTime from, DateTime to})>[];

  /// Si se asigna, las consultas esperan a que se complete: sirve para ver
  /// la pantalla mientras carga.
  Completer<void>? gate;

  @override
  Future<List<MonthlyTotal>> fetchMonthlyTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    requests.add((from: from, to: to));
    await gate?.future;
    if (error != null) throw error!;

    final totals = <(DateTime, TransactionType, String?), (double, int)>{};
    for (final t in transactions) {
      if (t.type == TransactionType.transfer) continue;
      final month = DateTime(t.date.year, t.date.month);
      if (month.isBefore(from) || month.isAfter(to)) continue;

      final key = (month, t.type, t.categoryId);
      final (sum, count) = totals[key] ?? (0.0, 0);
      totals[key] = (sum + t.amount, count + 1);
    }

    return _monthlyTotals(totals);
  }

  /// Cuántas veces se pidieron los flujos por cuenta.
  var flowRequests = 0;

  /// Un error solo para los flujos por cuenta (los totales mensuales siguen bien).
  Object? flowsError;

  /// Imita `v_monthly_account_flows`: una transferencia resta en el origen y
  /// suma en el destino.
  @override
  Future<List<AccountFlow>> fetchAccountFlows() async {
    flowRequests++;
    await gate?.future;
    if (flowsError != null) throw flowsError!;
    if (error != null) throw error!;

    final flows = <(DateTime, String), int>{};
    void add(DateTime month, String accountId, int cents) {
      final key = (month, accountId);
      flows[key] = (flows[key] ?? 0) + cents;
    }

    for (final t in transactions) {
      final month = DateTime(t.date.year, t.date.month);
      final cents = (t.amount * 100).round();
      switch (t.type) {
        case TransactionType.income:
          add(month, t.accountId, cents);
        case TransactionType.expense:
          add(month, t.accountId, -cents);
        case TransactionType.transfer:
          add(month, t.accountId, -cents);
          add(month, t.destinationAccountId!, cents);
      }
    }

    return [
      for (final MapEntry(key: (month, accountId), value: cents) in flows.entries)
        AccountFlow(month: month, accountId: accountId, currency: 'COP', cents: cents),
    ];
  }

  List<MonthlyTotal> _monthlyTotals(
    Map<(DateTime, TransactionType, String?), (double, int)> totals,
  ) {
    return [
      for (final MapEntry(key: (month, type, categoryId), value: (sum, count))
          in totals.entries)
        MonthlyTotal(
          month: month,
          currency: 'COP',
          type: type,
          categoryId: categoryId,
          total: sum,
          movements: count,
        ),
    ];
  }
}

class _StoredDebt {
  _StoredDebt({
    required this.id,
    required this.direction,
    required this.counterparty,
    required this.amount,
    required this.startDate,
    this.dueDate,
    this.notes,
    this.isArchived = false,
  });

  final String id;
  final DebtDirection direction;
  String counterparty;
  double amount;
  final DateTime startDate;
  DateTime? dueDate;
  String? notes;
  bool isArchived;
}

/// Imita las funciones `create_debt` y `register_debt_payment` y las vistas
/// de deudas: lo pagado sale de los movimientos enlazados, que se comparten
/// con las cuentas para que los saldos cambien como en la base real.
class FakeDebtRepository implements DebtRepository {
  FakeDebtRepository(this._transactions, this._accounts);

  final List<Transaction> _transactions;
  final FakeAccountRepository _accounts;
  final _debts = <_StoredDebt>[];
  final _links = <({String debtId, String transactionId})>[];
  var _next = 1;

  /// Error que lanzarán todas las operaciones mientras no sea null.
  Object? error;

  final calls = <String>[];

  /// Agrega una deuda ya hecha, con sus abonos, sin pasar por la interfaz.
  /// Devuelve su id.
  String seedDebt({
    DebtDirection direction = DebtDirection.payable,
    String counterparty = 'Juan',
    double amount = 500000,
    List<double> payments = const [],
    DateTime? startDate,
    DateTime? dueDate,
    String? notes,
    bool archived = false,
    String accountId = 'id-Bancolombia',
  }) {
    final debt = _StoredDebt(
      id: 'debt-${_next++}',
      direction: direction,
      counterparty: counterparty,
      amount: amount,
      startDate: startDate ?? DateTime(2026, 1, 1),
      dueDate: dueDate,
      notes: notes,
      isArchived: archived,
    );
    _debts.add(debt);
    for (final payment in payments) {
      _addPayment(debt, accountId, payment, DateTime(2026, 2, 1));
    }
    return debt.id;
  }

  double _paid(_StoredDebt debt) => _links
      .where((link) => link.debtId == debt.id)
      .map(
        (link) => _transactions
            .where((t) => t.id == link.transactionId)
            .map((t) => t.amount)
            .fold(0.0, (a, b) => a + b),
      )
      .fold(0.0, (a, b) => a + b);

  String _addPayment(_StoredDebt debt, String accountId, double amount, DateTime date) {
    final id = 'debt-tx-${_next++}';
    final payable = debt.direction == DebtDirection.payable;
    _transactions.add(
      Transaction(
        id: id,
        type: payable ? TransactionType.expense : TransactionType.income,
        accountId: accountId,
        amount: amount,
        date: date,
        description: '${payable ? 'Abono a' : 'Abono de'} ${debt.counterparty}',
      ),
    );
    _links.add((debtId: debt.id, transactionId: id));
    return id;
  }

  /// Falla como la base de datos: con su código y, si lo trae, el código
  /// estable de la validación en `details`.
  Never _fail(String message, String code, [String? details]) =>
      throw PostgrestException(message: message, code: code, details: details);

  @override
  Future<List<Debt>> fetchAll() async {
    calls.add('fetchAll');
    if (error != null) throw error!;
    return [
      for (final debt in _debts)
        Debt(
          id: debt.id,
          direction: debt.direction,
          counterparty: debt.counterparty,
          amount: debt.amount,
          paid: _paid(debt),
          remaining: debt.amount - _paid(debt),
          currency: 'COP',
          startDate: debt.startDate,
          dueDate: debt.dueDate,
          notes: debt.notes,
          isArchived: debt.isArchived,
        ),
    ]..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  @override
  Future<List<DebtPayment>> fetchPayments(String debtId) async {
    calls.add('fetchPayments:$debtId');
    if (error != null) throw error!;
    return [
      for (final link in _links.where((link) => link.debtId == debtId))
        for (final t in _transactions.where((t) => t.id == link.transactionId))
          DebtPayment(
            id: 'pay-${t.id}',
            debtId: debtId,
            transactionId: t.id,
            amount: t.amount,
            date: t.date,
            accountId: t.accountId,
            description: t.description,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> create(DebtDraft draft) async {
    calls.add('create:${draft.direction.name}:${draft.counterparty}:${draft.amount}:${draft.accountId}');
    if (error != null) throw error!;

    final accountId = draft.accountId;
    if (accountId != null && !_accounts.accounts.any((a) => a.id == accountId)) {
      _fail('La cuenta no existe', '23503', 'account_not_found');
    }

    final debt = _StoredDebt(
      id: 'debt-${_next++}',
      direction: draft.direction,
      counterparty: draft.counterparty,
      amount: double.parse(draft.amount),
      startDate: draft.startDate,
      dueDate: draft.dueDate,
      notes: draft.notes,
    );
    _debts.add(debt);

    if (accountId != null) {
      final payable = draft.direction == DebtDirection.payable;
      _transactions.add(
        Transaction(
          id: 'debt-tx-${_next++}',
          type: payable ? TransactionType.income : TransactionType.expense,
          accountId: accountId,
          amount: debt.amount,
          date: draft.startDate,
          description:
              draft.description ??
              '${payable ? 'Préstamo de' : 'Préstamo a'} ${debt.counterparty}',
        ),
      );
    }
  }

  @override
  Future<void> update(
    String id, {
    required String counterparty,
    required String amount,
    DateTime? dueDate,
    String? notes,
  }) async {
    calls.add('update:$id:$counterparty:$amount');
    if (error != null) throw error!;
    final debt = _debts.firstWhere((d) => d.id == id);
    final newAmount = double.parse(amount);
    if (newAmount < _paid(debt)) {
      _fail(
        'El monto no puede ser menor a lo que ya se ha pagado',
        '23514',
        'debt_amount_below_paid',
      );
    }
    debt
      ..counterparty = counterparty
      ..amount = newAmount
      ..dueDate = dueDate
      ..notes = notes;
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) async {
    calls.add('setArchived:$id:$isArchived');
    if (error != null) throw error!;
    _debts.firstWhere((d) => d.id == id).isArchived = isArchived;
  }

  @override
  Future<void> registerPayment({
    required String debtId,
    required String accountId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    calls.add('registerPayment:$debtId:$accountId:$amount');
    if (error != null) throw error!;

    final debt = _debts.where((d) => d.id == debtId).firstOrNull;
    if (debt == null) _fail('La deuda no existe', '23503', 'debt_not_found');
    if (debt.isArchived) {
      _fail(
        'La deuda está archivada: restáurala para registrar abonos',
        '23514',
        'debt_archived',
      );
    }
    final value = double.parse(amount);
    if (_paid(debt) + value > debt.amount) {
      _fail(
        'El abono supera lo que falta por pagar',
        '23514',
        'payment_exceeds_remaining',
      );
    }

    final id = _addPayment(debt, accountId, value, date);
    if (description != null) {
      final index = _transactions.indexWhere((t) => t.id == id);
      final t = _transactions[index];
      _transactions[index] = Transaction(
        id: t.id,
        type: t.type,
        accountId: t.accountId,
        amount: t.amount,
        date: t.date,
        description: description,
      );
    }
  }
}

/// Imita la tabla `budgets`: una regla por categoría y mes, que se reemplaza al
/// definirla de nuevo (como el `upsert` de la base de datos).
class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository([List<BudgetRule> rules = const []])
    : rules = [...rules];

  final List<BudgetRule> rules;
  Object? error;
  final calls = <String>[];

  /// Si se asigna, las consultas esperan a que se complete.
  Completer<void>? gate;

  @override
  Future<List<BudgetRule>> fetchAll() async {
    calls.add('fetchAll');
    await gate?.future;
    if (error != null) throw error!;
    return [...rules];
  }

  @override
  Future<void> set({
    required String categoryId,
    required DateTime month,
    required String amount,
  }) async {
    calls.add('set $categoryId ${month.year}-${month.month} $amount');
    if (error != null) throw error!;

    final first = DateTime(month.year, month.month);
    final existing = rules.indexWhere(
      (rule) => rule.categoryId == categoryId && rule.month == first,
    );
    final rule = BudgetRule(
      id: existing >= 0 ? rules[existing].id : 'budget-${rules.length + 1}',
      categoryId: categoryId,
      month: first,
      cents: (double.parse(amount) * 100).round(),
    );
    if (existing >= 0) {
      rules[existing] = rule;
    } else {
      rules.add(rule);
    }
  }
}

/// Cuentas, categorías y movimientos enlazados, como la base de datos real.
class FakeBackend {
  factory FakeBackend({
    List<Account> accounts = const [],
    List<Category> categories = const [],
    List<Transaction> transactions = const [],
    List<BudgetRule> budgets = const [],
  }) {
    final shared = [...transactions];
    final accountsRepository = FakeAccountRepository(accounts, shared);
    return FakeBackend._(
      accountsRepository,
      FakeTransactionRepository(shared),
      FakeCategoryRepository(categories),
      FakeSummaryRepository(shared),
      FakeDebtRepository(shared, accountsRepository),
      FakeBudgetRepository(budgets),
    );
  }

  FakeBackend._(
    this.accounts,
    this.transactions,
    this.categories,
    this.summary,
    this.debts,
    this.budgets,
  );

  final FakeAccountRepository accounts;
  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeSummaryRepository summary;
  final FakeDebtRepository debts;
  final FakeBudgetRepository budgets;
}
