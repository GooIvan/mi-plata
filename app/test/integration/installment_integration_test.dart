// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/debts/data/debt_repository.dart';
import 'package:mi_plata/features/debts/domain/debt.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/debts/domain/debt_draft.dart';
import 'package:mi_plata/features/debts/domain/installment_plan_draft.dart';
import 'package:mi_plata/features/recurring/data/recurring_repository.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:mi_plata/features/recurring/domain/recurring_payment.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_error_message.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

late AppLocalizations l10n;

Matcher failsWith(String code, [String? details]) => throwsA(
  isA<PostgrestException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.details, 'detalle', details ?? anything),
);

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group(
    'Deudas en cuotas contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      /// Un usuario nuevo con una cuenta en pesos y una en dólares.
      Future<
        ({
          SupabaseClient client,
          RecurringRepository recurring,
          DebtRepository debts,
          AccountRepository accounts,
          TransactionRepository transactions,
          Account bank,
          Account dollars,
          String category,
        })
      >
      newUser(String prefix) async {
        final client = await harness.signedUpClient(prefix);
        final accounts = AccountRepository(client);
        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '5000000',
          currency: 'COP',
        );
        await accounts.create(
          name: 'Dólares',
          type: AccountType.bank,
          initialBalance: '1000',
          currency: 'USD',
        );
        final all = await accounts.fetchAll();
        return (
          client: client,
          recurring: RecurringRepository(client),
          debts: DebtRepository(client),
          accounts: accounts,
          transactions: TransactionRepository(client),
          bank: all.firstWhere((a) => a.name == 'Bancolombia'),
          dollars: all.firstWhere((a) => a.name == 'Dólares'),
          category: (await CategoryRepository(client).fetchAll())
              .firstWhere((c) => c.type == CategoryType.expense)
              .id,
        );
      }

      InstallmentPlanDraft plan(
        Account account, {
        String name = 'TV Samsung',
        String total = '2400000',
        int installments = 12,
        String installment = '200000',
        Recurrence recurrence = Recurrence.monthly,
        DateTime? firstDue,
        String? categoryId,
      }) => InstallmentPlanDraft(
        counterparty: name,
        amount: total,
        installments: installments,
        installmentAmount: installment,
        recurrence: recurrence,
        firstDue: firstDue ?? DateTime(2026, 11, 5),
        accountId: account.id,
        categoryId: categoryId,
        startDate: DateTime(2026, 10, 23),
      );

      Future<RecurringPayment> only(RecurringRepository repo) async =>
          (await repo.fetchAll()).single;

      Future<Debt> theDebt(DebtRepository debts) async =>
          (await debts.fetchAll()).single;

      Future<void> pay(
        RecurringRepository recurring,
        RecurringPayment plan,
        Account account, {
        String? amount,
        DateTime? date,
      }) => recurring.confirm(
        id: plan.id,
        accountId: account.id,
        amount: amount ?? plan.nextAmount.toString(),
        date: date ?? DateTime(2026, 11, 5),
      );

      group('crear la compra a cuotas', () {
        test('crea la deuda y su plan juntos, sin mover dinero', () async {
          final ana = await newUser('cuotas');
          final before = (await ana.accounts.fetchAll()).map((a) => a.currentBalance).toList();

          await ana.debts.createWithInstallments(
            plan(ana.bank, categoryId: ana.category),
          );

          final debt = await theDebt(ana.debts);
          expect(debt.counterparty, 'TV Samsung');
          expect(debt.direction, DebtDirection.payable);
          expect(debt.amount, 2400000);
          expect(debt.currency, 'COP');
          expect(debt.paid, 0);
          expect(debt.remaining, 2400000);

          final created = await only(ana.recurring);
          expect(created.debtId, debt.id);
          expect(created.name, 'TV Samsung');
          expect(created.amount, 200000);
          expect(created.installments, 12);
          expect(created.installmentsPaid, 0);
          expect(created.debtRemaining, 2400000);
          expect(created.accountId, ana.bank.id);
          expect(created.categoryId, ana.category);
          expect(created.recurrence, Recurrence.monthly);
          expect(created.nextDueDate, DateTime(2026, 11, 5));
          expect(created.anchorDay, 5);
          expect(created.currentInstallment, 1);

          // Comprar no mueve dinero.
          expect(await ana.transactions.fetchRecent(), isEmpty);
          expect(
            (await ana.accounts.fetchAll()).map((a) => a.currentBalance).toList(),
            before,
          );
        });

        test('la deuda es en la moneda de la cuenta con que se pagan las cuotas', () async {
          final ana = await newUser('cuotas');
          await ana.debts.createWithInstallments(
            plan(ana.dollars, name: 'Laptop', total: '1200', installment: '200', installments: 6),
          );

          expect((await theDebt(ana.debts)).currency, 'USD');
        });

        test('cada frecuencia guarda su cada cuánto', () async {
          final ana = await newUser('cuotas');
          await ana.debts.createWithInstallments(
            plan(ana.bank, recurrence: Recurrence.biweekly, firstDue: DateTime(2026, 10, 30)),
          );

          final created = await only(ana.recurring);
          expect(created.recurrence, Recurrence.biweekly);
          expect(created.anchorDay, 30);
        });

        test('si falla algo, no queda ni la deuda ni el plan', () async {
          final ana = await newUser('cuotas');

          // Cero cuotas: el plan se rechaza y la deuda ya creada se deshace.
          await expectLater(
            ana.debts.createWithInstallments(plan(ana.bank, installments: 0)),
            failsWith('23514'),
          );
          // Una cuota de cero también.
          await expectLater(
            ana.debts.createWithInstallments(plan(ana.bank, installment: '0')),
            failsWith('23514'),
          );

          expect(await ana.debts.fetchAll(), isEmpty);
          expect(await ana.recurring.fetchAll(), isEmpty);
        });

        test('una cuenta que no existe, o ajena, no se acepta', () async {
          final ana = await newUser('cuotas');
          final beto = await newUser('beto');

          try {
            await ana.debts.createWithInstallments(plan(beto.bank));
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23503');
            expect(error.details, 'account_not_found');
          }
          expect(await ana.debts.fetchAll(), isEmpty);
        });

        test('una categoría de ingreso no sirve', () async {
          final ana = await newUser('cuotas');
          final income = (await CategoryRepository(ana.client).fetchAll())
              .firstWhere((c) => c.type == CategoryType.income)
              .id;

          await expectLater(
            ana.debts.createWithInstallments(plan(ana.bank, categoryId: income)),
            failsWith('23514', 'recurring_category_mismatch'),
          );
          expect(await ana.debts.fetchAll(), isEmpty);
        });
      });

      group('confirmar una cuota', () {
        test('registra un abono a la deuda, ligado al plan', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank, categoryId: ana.category));
          final created = await only(ana.recurring);

          await pay(ana.recurring, created, ana.bank, date: DateTime(2026, 11, 6));

          // El abono es un gasto real, con la categoría del plan.
          final expense = (await ana.transactions.fetchRecent()).single;
          expect(expense.type, TransactionType.expense);
          expect(expense.amount, 200000);
          expect(expense.categoryId, ana.category);
          expect(expense.description, 'TV Samsung');
          expect(expense.date, DateTime(2026, 11, 6));

          // La deuda lo cuenta como abono.
          final debt = await theDebt(ana.debts);
          expect(debt.paid, 200000);
          expect(debt.remaining, 2200000);
          final payments = await ana.debts.fetchPayments(debt.id);
          expect(payments.single.amount, 200000);

          // Y el plan sabe que van una cuota pagada y pasó a la fecha siguiente.
          final after = await only(ana.recurring);
          expect(after.installmentsPaid, 1);
          expect(after.currentInstallment, 2);
          expect(after.debtRemaining, 2200000);
          expect(after.nextDueDate, DateTime(2026, 12, 5));
          expect((await ana.accounts.fetchAll()).firstWhere((a) => a.name == 'Bancolombia').currentBalance, 4800000);
          // El historial del plan trae ese gasto.
          expect(await ana.recurring.fetchPayments(created.id), hasLength(1));
        });

        test('se puede pagar un monto distinto, y la deuda baja por lo pagado', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          await pay(ana.recurring, created, ana.bank, amount: '250000');

          expect((await theDebt(ana.debts)).remaining, 2150000);
        });

        test('la última cuota es lo que falte, y al pagarla el plan termina solo', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(
            plan(ana.bank, total: '100', installments: 3, installment: '33.34'),
          );

          for (var i = 0; i < 3; i++) {
            final current = await only(ana.recurring);
            expect(current.currentInstallment, i + 1);
            // La tercera propone 33,32: lo que falta, no la cuota entera.
            await pay(ana.recurring, current, ana.bank);
          }

          final debt = await theDebt(ana.debts);
          expect(debt.isSettled, isTrue);
          expect(debt.paid, 100);

          // Sin fecha final, termina porque la deuda se saldó.
          final finished = await only(ana.recurring);
          expect(finished.nextDueDate, isNull);
          expect(finished.isFinished, isTrue);
          expect(finished.debtRemaining, 0);
          expect(finished.installmentsPaid, 3);
        });

        test('no se puede pagar más de lo que falta', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(
            plan(ana.bank, total: '100', installments: 2, installment: '60'),
          );
          final created = await only(ana.recurring);

          try {
            await pay(ana.recurring, created, ana.bank, amount: '100.01');
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'payment_exceeds_remaining');
            expect(recurringErrorMessage(l10n, error), 'El abono supera lo que falta por pagar');
          }

          // Nada cambió: ni abono, ni movimiento, ni fecha.
          expect((await theDebt(ana.debts)).paid, 0);
          expect(await ana.transactions.fetchRecent(), isEmpty);
          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 11, 5));
        });

        test('la cuenta tiene que ser de la moneda de la deuda', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          await expectLater(
            pay(ana.recurring, created, ana.dollars, amount: '100'),
            failsWith('23514', 'payment_currency_mismatch'),
          );
          expect(await ana.transactions.fetchRecent(), isEmpty);
          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 11, 5));
        });

        test('una deuda archivada no admite cuotas', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank));
          await ana.debts.setArchived((await theDebt(ana.debts)).id, isArchived: true);

          await expectLater(
            pay(ana.recurring, await only(ana.recurring), ana.bank),
            failsWith('23514', 'debt_archived'),
          );
        });

        test('omitir una cuota no cambia lo que se debe', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          await ana.recurring.skip(created.id);

          final after = await only(ana.recurring);
          expect(after.nextDueDate, DateTime(2026, 12, 5));
          expect(after.debtRemaining, 2400000);
          expect(after.installmentsPaid, 0);
          expect(after.currentInstallment, 1); // sigue sin pagarse la primera
          expect(await ana.transactions.fetchRecent(), isEmpty);
        });

        test('un abono suelto cuenta como cuota pagada', () async {
          final ana = await newUser('conf');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final debt = await theDebt(ana.debts);

          await ana.debts.registerPayment(
            debtId: debt.id,
            accountId: ana.bank.id,
            amount: '200000',
            date: DateTime(2026, 11, 1),
          );

          final after = await only(ana.recurring);
          expect(after.installmentsPaid, 1);
          expect(after.debtRemaining, 2200000);
        });
      });

      group('cuando la deuda se salda por otro lado', () {
        test('el plan lo ve: no quedan cuotas, y confirmar ya no sirve', () async {
          final ana = await newUser('salda');
          await ana.debts.createWithInstallments(
            plan(ana.bank, total: '400000', installments: 2),
          );
          final debt = await theDebt(ana.debts);

          await ana.debts.registerPayment(
            debtId: debt.id,
            accountId: ana.bank.id,
            amount: '400000',
            date: DateTime(2026, 11, 1),
          );

          final created = await only(ana.recurring);
          expect(created.debtRemaining, 0);
          expect(created.isSettled, isTrue);
          expect(created.isFinished, isTrue);
          expect(created.nextDueDate, DateTime(2026, 11, 5)); // aún guarda la fecha
          await expectLater(
            pay(ana.recurring, created, ana.bank, amount: '1000'),
            failsWith('23514', 'payment_exceeds_remaining'),
          );
        });

        test('omitir cuando ya está saldada cierra el plan', () async {
          final ana = await newUser('salda');
          await ana.debts.createWithInstallments(plan(ana.bank, total: '400000', installments: 2));
          final debt = await theDebt(ana.debts);
          await ana.debts.registerPayment(
            debtId: debt.id,
            accountId: ana.bank.id,
            amount: '400000',
            date: DateTime(2026, 11, 1),
          );

          await ana.recurring.skip((await only(ana.recurring)).id);

          expect((await only(ana.recurring)).nextDueDate, isNull);
        });
      });

      group('las reglas del plan', () {
        test('solo una deuda que debo puede pagarse en cuotas', () async {
          final ana = await newUser('reglas');
          await ana.debts.create(
            DebtDraft(
              direction: DebtDirection.receivable,
              counterparty: 'María',
              amount: '1000',
              startDate: DateTime(2026, 10, 1),
              currency: 'COP',
            ),
          );
          final owed = await theDebt(ana.debts);

          try {
            await ana.client.from('recurring_payments').insert({
              'name': 'Cobro',
              'amount': '100',
              'account_id': ana.bank.id,
              'every': 1,
              'unit': 'month',
              'next_due_date': '2026-11-05',
              'anchor_day': 5,
              'debt_id': owed.id,
              'installments': 10,
            });
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'installment_debt_direction');
            expect(
              recurringErrorMessage(l10n, error),
              'Solo las deudas que debes pueden pagarse en cuotas',
            );
          }
        });

        test('la cuenta del plan tiene que ser de la moneda de la deuda', () async {
          final ana = await newUser('reglas');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          try {
            await ana.client
                .from('recurring_payments')
                .update({'account_id': ana.dollars.id})
                .eq('id', created.id);
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'installment_account_currency');
            expect(
              recurringErrorMessage(l10n, error),
              'La cuenta de las cuotas tiene que ser de la moneda de la deuda',
            );
          }
          expect((await only(ana.recurring)).accountId, ana.bank.id);
        });

        test('una deuda tiene un solo plan', () async {
          final ana = await newUser('reglas');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          await expectLater(
            ana.client.from('recurring_payments').insert({
              'name': 'Otro plan',
              'amount': '100',
              'account_id': ana.bank.id,
              'every': 1,
              'unit': 'month',
              'next_due_date': '2026-11-05',
              'anchor_day': 5,
              'debt_id': created.debtId,
            }),
            failsWith('23505'),
          );
        });

        test('las cuotas pactadas piden una deuda, y tienen un rango', () async {
          final ana = await newUser('reglas');
          Map<String, dynamic> row(int installments) => {
            'name': 'Suelto',
            'amount': '100',
            'account_id': ana.bank.id,
            'every': 1,
            'unit': 'month',
            'next_due_date': '2026-11-05',
            'anchor_day': 5,
            'installments': installments,
          };

          await expectLater(
            ana.client.from('recurring_payments').insert(row(12)), // sin deuda
            failsWith('23514'),
          );
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);
          for (final bad in [0, 361]) {
            await expectLater(
              ana.client.from('recurring_payments').update({'installments': bad}).eq('id', created.id),
              failsWith('23514'),
            );
          }
        });

        test('borrar la deuda se lleva su plan', () async {
          final ana = await newUser('reglas');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final debt = await theDebt(ana.debts);
          await ana.client.from('debts').delete().eq('id', debt.id);

          expect(await ana.recurring.fetchAll(), isEmpty);
        });

        test('borrar el plan deja la deuda y sus abonos', () async {
          final ana = await newUser('reglas');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);
          await pay(ana.recurring, created, ana.bank);

          await ana.recurring.delete(created.id);

          expect(await ana.recurring.fetchAll(), isEmpty);
          final debt = await theDebt(ana.debts);
          expect(debt.paid, 200000);
          expect(await ana.transactions.fetchRecent(), hasLength(1));
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no ve ni toca el plan', () async {
          final ana = await newUser('ana');
          final beto = await newUser('beto');
          await ana.debts.createWithInstallments(plan(ana.bank));
          final created = await only(ana.recurring);

          expect(await beto.recurring.fetchAll(), isEmpty);
          expect(await beto.debts.fetchAll(), isEmpty);
          await expectLater(
            pay(beto.recurring, created, beto.bank),
            failsWith('23503', 'recurring_not_found'),
          );
          expect((await theDebt(ana.debts)).paid, 0);
        });
      });
    },
  );
}
