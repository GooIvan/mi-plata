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
import 'package:mi_plata/features/recurring/data/recurring_repository.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:mi_plata/features/recurring/domain/recurring_draft.dart';
import 'package:mi_plata/features/recurring/domain/recurring_payment.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_error_message.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
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
    'RecurringRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      /// Un usuario nuevo con una cuenta, y sus repositorios.
      Future<
        ({
          SupabaseClient client,
          RecurringRepository recurring,
          AccountRepository accounts,
          TransactionRepository transactions,
          Account bank,
          String expenseCategory,
          String incomeCategory,
        })
      >
      newUser(String prefix) async {
        final client = await harness.signedUpClient(prefix);
        final accounts = AccountRepository(client);
        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '1000000',
          currency: 'COP',
        );
        final categories = await CategoryRepository(client).fetchAll();
        return (
          client: client,
          recurring: RecurringRepository(client),
          accounts: accounts,
          transactions: TransactionRepository(client),
          bank: (await accounts.fetchAll()).single,
          expenseCategory: categories.firstWhere((c) => c.type == CategoryType.expense).id,
          incomeCategory: categories.firstWhere((c) => c.type == CategoryType.income).id,
        );
      }

      RecurringDraft draft(
        Account account, {
        String name = 'Netflix',
        String amount = '30000',
        String? categoryId,
        Recurrence recurrence = Recurrence.monthly,
        DateTime? next,
        DateTime? end,
      }) => RecurringDraft(
        name: name,
        amount: amount,
        accountId: account.id,
        categoryId: categoryId,
        recurrence: recurrence,
        nextDueDate: next ?? DateTime(2026, 11, 5),
        endDate: end,
      );

      Future<RecurringPayment> only(RecurringRepository repo) async =>
          (await repo.fetchAll()).single;

      Future<double> balance(AccountRepository accounts) async =>
          (await accounts.fetchAll()).single.currentBalance;

      group('crear y leer', () {
        test('guarda todo y calcula el día que se conserva', () async {
          final ana = await newUser('rec');
          await ana.recurring.create(
            draft(
              ana.bank,
              name: 'Arriendo',
              amount: '1500000.50',
              categoryId: ana.expenseCategory,
              recurrence: Recurrence.quarterly,
              next: DateTime(2026, 12, 31),
              end: DateTime(2028, 12, 31),
            ),
          );

          final payment = await only(ana.recurring);
          expect(payment.name, 'Arriendo');
          expect(payment.amount, 1500000.5);
          expect(payment.accountId, ana.bank.id);
          expect(payment.categoryId, ana.expenseCategory);
          expect(payment.recurrence, Recurrence.quarterly);
          expect(payment.nextDueDate, DateTime(2026, 12, 31));
          expect(payment.anchorDay, 31);
          expect(payment.endDate, DateTime(2028, 12, 31));
          expect(payment.isPaused, isFalse);
          expect(payment.isFinished, isFalse);
        });

        test('la lista sale por fecha, con los terminados al final', () async {
          final ana = await newUser('rec');
          await ana.recurring.create(draft(ana.bank, name: 'C', next: DateTime(2026, 12, 1)));
          await ana.recurring.create(draft(ana.bank, name: 'A', next: DateTime(2026, 11, 1)));
          await ana.recurring.create(
            draft(ana.bank, name: 'Z', next: DateTime(2026, 11, 2), end: DateTime(2026, 11, 2)),
          );
          await ana.recurring.skip((await ana.recurring.fetchAll()).firstWhere((p) => p.name == 'Z').id);

          expect((await ana.recurring.fetchAll()).map((p) => p.name), ['A', 'C', 'Z']);
        });

        test('se puede editar, y la pausa no cambia al editar', () async {
          final ana = await newUser('rec');
          await ana.recurring.create(draft(ana.bank));
          final created = await only(ana.recurring);
          await ana.recurring.setPaused(created.id, paused: true);

          await ana.recurring.update(
            created.id,
            draft(ana.bank, name: 'Netflix Premium', amount: '45000', next: DateTime(2026, 11, 20)),
          );

          final edited = await only(ana.recurring);
          expect(edited.name, 'Netflix Premium');
          expect(edited.amount, 45000);
          expect(edited.nextDueDate, DateTime(2026, 11, 20));
          expect(edited.anchorDay, 20);
          expect(edited.isPaused, isTrue);
        });

        test('quitar la categoría y la fecha final al editar', () async {
          final ana = await newUser('rec');
          await ana.recurring.create(
            draft(ana.bank, categoryId: ana.expenseCategory, end: DateTime(2027, 6, 5)),
          );
          final created = await only(ana.recurring);

          await ana.recurring.update(created.id, draft(ana.bank));

          final edited = await only(ana.recurring);
          expect(edited.categoryId, isNull);
          expect(edited.endDate, isNull);
        });

        test('pausar y reanudar', () async {
          final ana = await newUser('rec');
          await ana.recurring.create(draft(ana.bank));
          final id = (await only(ana.recurring)).id;

          await ana.recurring.setPaused(id, paused: true);
          expect((await only(ana.recurring)).isPaused, isTrue);
          await ana.recurring.setPaused(id, paused: false);
          expect((await only(ana.recurring)).isPaused, isFalse);
        });
      });

      group('confirmar un pago', () {
        test('crea el gasto de verdad y pasa al mes siguiente', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(
            draft(ana.bank, categoryId: ana.expenseCategory, next: DateTime(2026, 10, 5)),
          );
          final payment = await only(ana.recurring);
          expect(await balance(ana.accounts), 1000000); // nada se descontó solo

          await ana.recurring.confirm(
            id: payment.id,
            accountId: ana.bank.id,
            amount: '30000',
            date: DateTime(2026, 10, 6),
          );

          expect(await balance(ana.accounts), 970000);
          final expense = (await ana.transactions.fetchRecent()).single;
          expect(expense.type, TransactionType.expense);
          expect(expense.amount, 30000);
          expect(expense.date, DateTime(2026, 10, 6));
          expect(expense.categoryId, ana.expenseCategory);
          expect(expense.description, 'Netflix'); // el nombre de la regla
          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 11, 5));
        });

        test('el monto, la fecha y la descripción pueden ser otros', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(draft(ana.bank));
          final payment = await only(ana.recurring);

          await ana.recurring.confirm(
            id: payment.id,
            accountId: ana.bank.id,
            amount: '35500.25',
            date: DateTime(2026, 11, 7),
            description: '  Con el aumento ',
          );

          final expense = (await ana.transactions.fetchRecent()).single;
          expect(expense.amount, 35500.25);
          expect(expense.description, 'Con el aumento');
          expect(await balance(ana.accounts), 964499.75);
        });

        test('una descripción en blanco usa el nombre de la regla', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(draft(ana.bank, name: 'Spotify'));
          final payment = await only(ana.recurring);

          await ana.recurring.confirm(
            id: payment.id,
            accountId: ana.bank.id,
            amount: '17900',
            date: DateTime(2026, 11, 5),
            description: '   ',
          );

          expect((await ana.transactions.fetchRecent()).single.description, 'Spotify');
        });

        test('se puede pagar desde otra cuenta', () async {
          final ana = await newUser('conf');
          await ana.accounts.create(
            name: 'Nequi',
            type: AccountType.wallet,
            initialBalance: '50000',
            currency: 'COP',
          );
          final nequi = (await ana.accounts.fetchAll()).firstWhere((a) => a.name == 'Nequi');
          await ana.recurring.create(draft(ana.bank));

          await ana.recurring.confirm(
            id: (await only(ana.recurring)).id,
            accountId: nequi.id,
            amount: '30000',
            date: DateTime(2026, 11, 5),
          );

          final accounts = {for (final a in await ana.accounts.fetchAll()) a.name: a.currentBalance};
          expect(accounts, {'Bancolombia': 1000000, 'Nequi': 20000});
        });

        test('cada confirmación avanza una fecha', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(draft(ana.bank, next: DateTime(2026, 1, 31)));
          final id = (await only(ana.recurring)).id;

          final dates = <DateTime?>[];
          for (var i = 0; i < 4; i++) {
            await ana.recurring.confirm(
              id: id,
              accountId: ana.bank.id,
              amount: '1000',
              date: DateTime(2026, 1, 1),
            );
            dates.add((await only(ana.recurring)).nextDueDate);
          }

          // Un pago del 31 cae el último día de cada mes y vuelve al 31.
          expect(dates, [
            DateTime(2026, 2, 28),
            DateTime(2026, 3, 31),
            DateTime(2026, 4, 30),
            DateTime(2026, 5, 31),
          ]);
          expect(await ana.transactions.fetchRecent(), hasLength(4));
        });

        test('al pasarse de la fecha final, el pago termina', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(
            draft(ana.bank, next: DateTime(2026, 11, 5), end: DateTime(2026, 12, 20)),
          );
          final id = (await only(ana.recurring)).id;

          await ana.recurring.confirm(
            id: id,
            accountId: ana.bank.id,
            amount: '1000',
            date: DateTime(2026, 11, 5),
          );
          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 12, 5));

          await ana.recurring.confirm(
            id: id,
            accountId: ana.bank.id,
            amount: '1000',
            date: DateTime(2026, 12, 5),
          );
          final finished = await only(ana.recurring);
          expect(finished.nextDueDate, isNull);
          expect(finished.isFinished, isTrue);
        });

        test('un pago terminado ya no se confirma ni se omite', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(
            draft(ana.bank, next: DateTime(2026, 11, 5), end: DateTime(2026, 11, 5)),
          );
          final id = (await only(ana.recurring)).id;
          await ana.recurring.skip(id);

          try {
            await ana.recurring.confirm(
              id: id,
              accountId: ana.bank.id,
              amount: '1000',
              date: DateTime(2026, 11, 5),
            );
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'recurring_finished');
            expect(recurringErrorMessage(l10n, error), 'Este pago recurrente ya terminó');
          }
          await expectLater(ana.recurring.skip(id), failsWith('23514', 'recurring_finished'));
          expect(await ana.transactions.fetchRecent(), isEmpty);
        });

        test('un pago en pausa todavía se puede confirmar', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(draft(ana.bank));
          final id = (await only(ana.recurring)).id;
          await ana.recurring.setPaused(id, paused: true);

          await ana.recurring.confirm(
            id: id,
            accountId: ana.bank.id,
            amount: '1000',
            date: DateTime(2026, 11, 5),
          );

          expect((await only(ana.recurring)).isPaused, isTrue);
          expect(await ana.transactions.fetchRecent(), hasLength(1));
        });

        test('si el gasto no se puede crear, la regla no avanza', () async {
          final ana = await newUser('conf');
          await ana.recurring.create(draft(ana.bank));
          final payment = await only(ana.recurring);

          // Un monto negativo falla en el gasto: todo se deshace.
          await expectLater(
            ana.recurring.confirm(
              id: payment.id,
              accountId: ana.bank.id,
              amount: '-5',
              date: DateTime(2026, 11, 5),
            ),
            failsWith('23514'),
          );

          expect((await only(ana.recurring)).nextDueDate, payment.nextDueDate);
          expect(await ana.transactions.fetchRecent(), isEmpty);
          expect(await balance(ana.accounts), 1000000);
        });

        test('una cuenta que no existe, o ajena, no se acepta', () async {
          final ana = await newUser('conf');
          final beto = await newUser('beto');
          await ana.recurring.create(draft(ana.bank));
          final id = (await only(ana.recurring)).id;

          await expectLater(
            ana.recurring.confirm(
              id: id,
              accountId: '00000000-0000-0000-0000-000000000000',
              amount: '1000',
              date: DateTime(2026, 11, 5),
            ),
            failsWith('23503'),
          );
          await expectLater(
            ana.recurring.confirm(
              id: id,
              accountId: beto.bank.id,
              amount: '1000',
              date: DateTime(2026, 11, 5),
            ),
            failsWith('23503'),
          );
          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 11, 5));
        });

        test('un pago que no existe', () async {
          final ana = await newUser('conf');
          try {
            await ana.recurring.confirm(
              id: '00000000-0000-0000-0000-000000000000',
              accountId: ana.bank.id,
              amount: '1000',
              date: DateTime(2026, 11, 5),
            );
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23503');
            expect(error.details, 'recurring_not_found');
            expect(
              recurringErrorMessage(l10n, error),
              'El pago recurrente ya no existe. Vuelve a abrir la pantalla.',
            );
          }
          await expectLater(
            ana.recurring.skip('00000000-0000-0000-0000-000000000000'),
            failsWith('23503', 'recurring_not_found'),
          );
        });
      });

      group('omitir un pago', () {
        test('pasa al siguiente sin crear ningún movimiento', () async {
          final ana = await newUser('omitir');
          await ana.recurring.create(draft(ana.bank, next: DateTime(2026, 12, 15)));
          final id = (await only(ana.recurring)).id;

          await ana.recurring.skip(id);

          expect((await only(ana.recurring)).nextDueDate, DateTime(2027, 1, 15));
          expect(await ana.transactions.fetchRecent(), isEmpty);
          expect(await balance(ana.accounts), 1000000);
        });

        test('cada frecuencia avanza como toca', () async {
          final ana = await newUser('omitir');
          final cases = {
            'semanal': (Recurrence.weekly, DateTime(2026, 12, 28), DateTime(2027, 1, 4)),
            'quincenal': (Recurrence.biweekly, DateTime(2026, 10, 23), DateTime(2026, 11, 6)),
            'mensual': (Recurrence.monthly, DateTime(2026, 1, 31), DateTime(2026, 2, 28)),
            'bimestral': (Recurrence.bimonthly, DateTime(2026, 11, 30), DateTime(2027, 1, 30)),
            'trimestral': (Recurrence.quarterly, DateTime(2026, 11, 30), DateTime(2027, 2, 28)),
            'semestral': (Recurrence.semiannual, DateTime(2026, 8, 31), DateTime(2027, 2, 28)),
            'anual': (Recurrence.yearly, DateTime(2028, 2, 29), DateTime(2029, 2, 28)),
          };
          for (final entry in cases.entries) {
            final (recurrence, from, _) = entry.value;
            await ana.recurring.create(
              draft(ana.bank, name: entry.key, recurrence: recurrence, next: from),
            );
          }
          for (final payment in await ana.recurring.fetchAll()) {
            await ana.recurring.skip(payment.id);
          }

          for (final payment in await ana.recurring.fetchAll()) {
            expect(payment.nextDueDate, cases[payment.name]!.$3, reason: payment.name);
          }
        });

        test('la base y la app calculan lo mismo', () async {
          final ana = await newUser('omitir');
          final starts = [
            DateTime(2026, 1, 31),
            DateTime(2026, 3, 31),
            DateTime(2028, 1, 29),
            DateTime(2026, 12, 15),
            DateTime(2026, 5, 1),
          ];
          for (final recurrence in Recurrence.presets) {
            for (final (i, start) in starts.indexed) {
              await ana.recurring.create(
                draft(
                  ana.bank,
                  name: '${recurrence.every}${recurrence.unit.name}-$i',
                  recurrence: recurrence,
                  next: start,
                ),
              );
            }
          }
          final before = {for (final p in await ana.recurring.fetchAll()) p.id: p};
          for (final id in before.keys) {
            await ana.recurring.skip(id);
          }

          for (final after in await ana.recurring.fetchAll()) {
            final old = before[after.id]!;
            final expected = old.recurrence.advance(old.nextDueDate!, anchorDay: old.anchorDay);
            expect(after.nextDueDate, expected, reason: old.name);
          }
        });
      });

      group('las reglas de la base', () {
        test('el nombre no puede estar vacío ni el monto ser cero o negativo', () async {
          final ana = await newUser('reglas');
          await expectLater(ana.recurring.create(draft(ana.bank, name: '   ')), failsWith('23514'));
          await expectLater(ana.recurring.create(draft(ana.bank, amount: '0')), failsWith('23514'));
          await expectLater(ana.recurring.create(draft(ana.bank, amount: '-10')), failsWith('23514'));
          expect(await ana.recurring.fetchAll(), isEmpty);
        });

        test('solo categorías de gasto, con un mensaje que se traduce', () async {
          final ana = await newUser('reglas');
          try {
            await ana.recurring.create(draft(ana.bank, categoryId: ana.incomeCategory));
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'recurring_category_mismatch');
            expect(
              error.message,
              'Solo las categorías de gasto sirven en un pago recurrente',
            );
            final english = await loadL10n('en');
            expect(
              recurringErrorMessage(english, error),
              'Only expense categories can be used in a recurring payment',
            );
          }
        });

        test('la fecha final no puede ser anterior al próximo pago', () async {
          final ana = await newUser('reglas');
          await expectLater(
            ana.recurring.create(
              draft(ana.bank, next: DateTime(2026, 11, 5), end: DateTime(2026, 11, 4)),
            ),
            failsWith('23514', 'recurring_end_before_due'),
          );
          // El mismo día sí.
          await ana.recurring.create(
            draft(ana.bank, next: DateTime(2026, 11, 5), end: DateTime(2026, 11, 5)),
          );
        });

        test('la cuenta tiene que existir y ser del usuario', () async {
          final ana = await newUser('reglas');
          final beto = await newUser('beto');
          await expectLater(ana.recurring.create(draft(beto.bank)), failsWith('23503'));
        });

        test('una frecuencia fuera de rango no se acepta', () async {
          final ana = await newUser('reglas');
          for (final every in [0, 100]) {
            await expectLater(
              ana.client.from('recurring_payments').insert({
                ...draft(ana.bank).toJson(),
                'every': every,
              }),
              failsWith('23514'),
            );
          }
          await expectLater(
            ana.client.from('recurring_payments').insert({
              ...draft(ana.bank).toJson(),
              'anchor_day': 32,
            }),
            failsWith('23514'),
          );
        });

        test('sin próxima fecha solo si tiene fecha final', () async {
          final ana = await newUser('reglas');
          await expectLater(
            ana.client.from('recurring_payments').insert({
              ...draft(ana.bank).toJson(),
              'next_due_date': null,
            }),
            failsWith('23514'),
          );
        });
      });

      group('historial y borrado', () {
        test('los gastos de un pago se encuentran por la regla', () async {
          final ana = await newUser('hist');
          await ana.recurring.create(draft(ana.bank, name: 'Netflix'));
          await ana.recurring.create(draft(ana.bank, name: 'Spotify'));
          final payments = {for (final p in await ana.recurring.fetchAll()) p.name: p.id};

          for (final (name, date) in [
            ('Netflix', DateTime(2026, 11, 5)),
            ('Netflix', DateTime(2026, 12, 5)),
            ('Spotify', DateTime(2026, 11, 8)),
          ]) {
            await ana.recurring.confirm(
              id: payments[name]!,
              accountId: ana.bank.id,
              amount: '1000',
              date: date,
            );
          }
          // Y un gasto cualquiera, sin regla: no sale en ningún historial.
          await ana.transactions.create(
            TransactionDraft(
              type: TransactionType.expense,
              accountId: ana.bank.id,
              amount: '500',
              date: DateTime(2026, 11, 9),
            ),
          );

          final netflix = await ana.recurring.fetchPayments(payments['Netflix']!);
          expect(netflix.map((t) => t.date), [DateTime(2026, 12, 5), DateTime(2026, 11, 5)]);
          expect(await ana.recurring.fetchPayments(payments['Spotify']!), hasLength(1));
          expect(await ana.transactions.fetchRecent(), hasLength(4));
        });

        test('borrar la regla deja los gastos que ya se registraron', () async {
          final ana = await newUser('hist');
          await ana.recurring.create(draft(ana.bank));
          final id = (await only(ana.recurring)).id;
          await ana.recurring.confirm(
            id: id,
            accountId: ana.bank.id,
            amount: '30000',
            date: DateTime(2026, 11, 5),
          );

          await ana.recurring.delete(id);

          expect(await ana.recurring.fetchAll(), isEmpty);
          final expense = (await ana.transactions.fetchRecent()).single;
          expect(expense.amount, 30000);
          expect(await balance(ana.accounts), 970000);
          // El enlace se perdió con la regla.
          final rows = await ana.client.from('transactions').select('recurring_payment_id');
          expect(rows.single['recurring_payment_id'], isNull);
        });

        test('borrar el gasto no deshace el avance de la regla', () async {
          final ana = await newUser('hist');
          await ana.recurring.create(draft(ana.bank, next: DateTime(2026, 11, 5)));
          final id = (await only(ana.recurring)).id;
          await ana.recurring.confirm(
            id: id,
            accountId: ana.bank.id,
            amount: '30000',
            date: DateTime(2026, 11, 5),
          );

          await ana.transactions.delete((await ana.transactions.fetchRecent()).single.id);

          expect((await only(ana.recurring)).nextDueDate, DateTime(2026, 12, 5));
          expect(await ana.recurring.fetchPayments(id), isEmpty);
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no ve mis pagos ni los de él me llegan', () async {
          final ana = await newUser('ana');
          final beto = await newUser('beto');
          await ana.recurring.create(draft(ana.bank, name: 'De Ana'));
          await beto.recurring.create(draft(beto.bank, name: 'De Beto'));

          expect((await ana.recurring.fetchAll()).single.name, 'De Ana');
          expect((await beto.recurring.fetchAll()).single.name, 'De Beto');
        });

        test('no puede confirmar, omitir, editar ni borrar los de otro', () async {
          final ana = await newUser('ana');
          final beto = await newUser('beto');
          await ana.recurring.create(draft(ana.bank));
          final id = (await only(ana.recurring)).id;

          await expectLater(
            beto.recurring.confirm(
              id: id,
              accountId: beto.bank.id,
              amount: '1000',
              date: DateTime(2026, 11, 5),
            ),
            failsWith('23503', 'recurring_not_found'),
          );
          await expectLater(beto.recurring.skip(id), failsWith('23503', 'recurring_not_found'));

          final stolen = await beto.client
              .from('recurring_payments')
              .update({'name': 'Mío ahora'})
              .eq('id', id)
              .select();
          expect(stolen, isEmpty);
          await beto.recurring.delete(id);

          final mine = await only(ana.recurring);
          expect(mine.name, 'Netflix');
          expect(mine.nextDueDate, DateTime(2026, 11, 5));
        });

        test('sin sesión no se ve nada', () async {
          final anonymous = RecurringRepository(harness.newClient());
          await expectLater(anonymous.fetchAll(), throwsA(isA<PostgrestException>()));
        });
      });
    },
  );
}
