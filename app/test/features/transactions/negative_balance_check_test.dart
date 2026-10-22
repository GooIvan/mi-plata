import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/transactions/domain/negative_balance_check.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/presentation/negative_balance_message.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';

final nequi = testAccount('Nequi', type: AccountType.wallet, balance: 4000);
final efectivo = testAccount('Efectivo', type: AccountType.cash, balance: 0);
final visa = testAccount('Visa', type: AccountType.card, balance: -50000);

TransactionDraft draft(
  TransactionType type,
  Account from,
  String amount, {
  Account? to,
}) => TransactionDraft(
  type: type,
  accountId: from.id,
  destinationAccountId: to?.id,
  amount: amount,
  date: DateTime(2026, 10, 22),
);

List<NegativeBalance> check(
  List<Account> accounts, {
  TransactionDraft? draft,
  Transaction? previous,
}) => NegativeBalanceCheck.after(
  accounts: accounts,
  draft: draft,
  previous: previous,
);

void main() {
  group('al crear', () {
    test('un gasto mayor al saldo deja la cuenta en negativo', () {
      final result = check([nequi], draft: draft(TransactionType.expense, nequi, '6000'));

      expect(result, hasLength(1));
      expect(result.single.account.name, 'Nequi');
      expect(result.single.balance, -2000);
    });

    test('dejar la cuenta exactamente en cero no avisa', () {
      expect(check([nequi], draft: draft(TransactionType.expense, nequi, '4000')), isEmpty);
    });

    test('un gasto dentro del saldo no avisa', () {
      expect(check([nequi], draft: draft(TransactionType.expense, nequi, '1500.50')), isEmpty);
    });

    test('un ingreso nunca avisa, ni en una cuenta que ya está en negativo', () {
      final overdrawn = testAccount('Banco', balance: -1000);
      expect(check([overdrawn], draft: draft(TransactionType.income, overdrawn, '500')), isEmpty);
    });

    test('una transferencia avisa por el origen y no por el destino', () {
      final result = check(
        [nequi, efectivo],
        draft: draft(TransactionType.transfer, nequi, '6000', to: efectivo),
      );

      expect(result.map((w) => w.account.name), ['Nequi']);
      expect(result.single.balance, -2000);
    });

    test('una cuenta que ya está en negativo avisa si el gasto lo empeora', () {
      final overdrawn = testAccount('Banco', balance: -1000);
      final result = check([overdrawn], draft: draft(TransactionType.expense, overdrawn, '500'));

      expect(result.single.balance, -1500);
    });

    test('las tarjetas quedan exentas: para ellas el negativo es lo normal', () {
      expect(check([visa], draft: draft(TransactionType.expense, visa, '20000')), isEmpty);
    });

    test('las cuentas archivadas no cuentan', () {
      final archived = testAccount('Vieja', balance: 100, archived: true);
      expect(check([archived], draft: draft(TransactionType.expense, archived, '500')), isEmpty);
    });

    test('suma en centavos: 0,10 + 0,20 menos 0,30 deja exactamente cero', () {
      final account = testAccount('Centavos', balance: 0.1 + 0.2);
      expect(check([account], draft: draft(TransactionType.expense, account, '0.30')), isEmpty);
    });
  });

  group('al editar', () {
    // Nequi empezó con 4.000, se gastaron 3.000 y hoy tiene 1.000.
    final spent = testTransaction(
      'tx-1',
      type: TransactionType.expense,
      accountId: nequi.id,
      amount: 3000,
      date: DateTime(2026, 10, 22),
    );
    final afterSpending = testAccount('Nequi', type: AccountType.wallet, balance: 1000);

    test('descuenta la versión anterior: subir el gasto a 3.500 no avisa', () {
      final result = check(
        [afterSpending],
        draft: draft(TransactionType.expense, afterSpending, '3500'),
        previous: spent,
      );

      expect(result, isEmpty); // 1.000 + 3.000 - 3.500 = 500
    });

    test('subir el gasto más allá del saldo real sí avisa', () {
      final result = check(
        [afterSpending],
        draft: draft(TransactionType.expense, afterSpending, '4500'),
        previous: spent,
      );

      expect(result.single.balance, -500);
    });

    test('guardar sin cambiar el monto no avisa, aunque la cuenta esté en negativo', () {
      final negative = testAccount('Nequi', type: AccountType.wallet, balance: -500);
      final result = check(
        [negative],
        draft: draft(TransactionType.expense, negative, '3000'),
        previous: spent,
      );

      expect(result, isEmpty);
    });

    test('bajar el monto nunca avisa', () {
      final negative = testAccount('Nequi', type: AccountType.wallet, balance: -500);
      final result = check(
        [negative],
        draft: draft(TransactionType.expense, negative, '2000'),
        previous: spent,
      );

      expect(result, isEmpty);
    });

    test('pasar una transferencia a gasto avisa por el destino que pierde el dinero', () {
      // Efectivo recibió 200.000, gastó 100.000 y hoy tiene 150.000 (empezó con 50.000).
      final cashNow = testAccount('Efectivo', type: AccountType.cash, balance: 150000);
      final bank = testAccount('Banco', balance: 1000000);
      final transfer = testTransaction(
        'tx-2',
        type: TransactionType.transfer,
        accountId: bank.id,
        destinationAccountId: cashNow.id,
        amount: 200000,
        date: DateTime(2026, 10, 22),
      );

      final result = check(
        [bank, cashNow],
        draft: draft(TransactionType.expense, bank, '200000'),
        previous: transfer,
      );

      expect(result.map((w) => w.account.name), ['Efectivo']);
      expect(result.single.balance, -50000);
    });

    test('puede avisar por varias cuentas a la vez', () {
      final a = testAccount('A', balance: 1000);
      final b = testAccount('B', balance: 1000);
      final incomeIntoA = testTransaction(
        'tx-3',
        type: TransactionType.income,
        accountId: a.id,
        amount: 5000,
        date: DateTime(2026, 10, 22),
      );

      // Lo que entraba a A ahora sale de B.
      final result = check(
        [a, b],
        draft: draft(TransactionType.expense, b, '5000'),
        previous: incomeIntoA,
      );

      expect(result.map((w) => w.account.name), ['A', 'B']);
      expect(result.map((w) => w.balance), [-4000, -4000]);
    });
  });

  group('al eliminar', () {
    test('borrar un ingreso que ya se gastó deja la cuenta en negativo', () {
      final income = testTransaction(
        'tx-4',
        type: TransactionType.income,
        accountId: nequi.id,
        amount: 5000,
        date: DateTime(2026, 10, 22),
      );
      final nowOnlyOneThousand = testAccount('Nequi', type: AccountType.wallet, balance: 1000);

      final result = check([nowOnlyOneThousand], previous: income);

      expect(result.single.balance, -4000);
    });

    test('borrar un gasto devuelve dinero y no avisa', () {
      final expense = testTransaction(
        'tx-5',
        type: TransactionType.expense,
        accountId: nequi.id,
        amount: 3000,
        date: DateTime(2026, 10, 22),
      );

      expect(check([nequi], previous: expense), isEmpty);
    });
  });

  test('el mensaje nombra cada cuenta, una por línea', () {
    final a = testAccount('A', balance: 1000);
    final b = testAccount('B', balance: 1000);

    final message = negativeBalanceMessage([
      NegativeBalance(account: a, balance: -4000),
      NegativeBalance(account: b, balance: -1500.5),
    ]);

    expect(message, 'A quedará en -\$4.000.\nB quedará en -\$1.500,50.');
  });
}
