// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/budgets/data/budget_repository.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/currency/data/currency_repository.dart';
import 'package:mi_plata/features/currency/presentation/currency_error_message.dart';
import 'package:mi_plata/features/debts/data/debt_repository.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/debts/domain/debt_draft.dart';
import 'package:mi_plata/features/summary/data/summary_repository.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

late AppLocalizations l10n;

/// Falla con ese código de la base, y si se pide, con el código estable que la
/// app traduce.
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
    'Multimoneda contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      /// Un usuario nuevo con sus repositorios.
      Future<
        ({
          SupabaseClient client,
          CurrencyRepository currency,
          AccountRepository accounts,
          TransactionRepository transactions,
          BudgetRepository budgets,
          DebtRepository debts,
        })
      >
      newUser(String prefix) async {
        final client = await harness.signedUpClient(prefix);
        return (
          client: client,
          currency: CurrencyRepository(client),
          accounts: AccountRepository(client),
          transactions: TransactionRepository(client),
          budgets: BudgetRepository(client),
          debts: DebtRepository(client),
        );
      }

      Future<Account> accountNamed(AccountRepository accounts, String name) async =>
          (await accounts.fetchAll()).firstWhere((a) => a.name == name);

      group('la moneda base', () {
        test('sin elegir ninguna es el peso colombiano', () async {
          final ana = await newUser('base');
          expect(await ana.currency.fetchBaseCurrency(), 'COP');
        });

        test('se puede cambiar, y queda guardada', () async {
          final ana = await newUser('base');
          await ana.currency.setBaseCurrency('USD');
          expect(await ana.currency.fetchBaseCurrency(), 'USD');

          await ana.currency.setBaseCurrency('EUR');
          expect(await ana.currency.fetchBaseCurrency(), 'EUR');
        });

        test('elegir la que ya es no hace nada', () async {
          final ana = await newUser('base');
          await ana.currency.setRate('USD', '4000');

          await ana.currency.setBaseCurrency('COP');

          expect(await ana.currency.fetchBaseCurrency(), 'COP');
          expect((await ana.currency.fetchRates()).single.rate, 4000);
        });

        test('cada usuario tiene la suya', () async {
          final ana = await newUser('ana');
          final beto = await newUser('beto');
          await ana.currency.setBaseCurrency('USD');

          expect(await beto.currency.fetchBaseCurrency(), 'COP');
        });

        test('no se puede escribir un código que no sean tres letras mayúsculas', () async {
          final ana = await newUser('base');
          await expectLater(
            ana.client.from('user_settings').insert({'base_currency': 'usd'}),
            failsWith('23514'),
          );
        });
      });

      group('las tasas de cambio', () {
        test('sin tasas, la lista está vacía', () async {
          final ana = await newUser('tasas');
          expect(await ana.currency.fetchRates(), isEmpty);
        });

        test('define una tasa con decimales exactos', () async {
          final ana = await newUser('tasas');
          await ana.currency.setRate('USD', '4012.5');
          await ana.currency.setRate('EUR', '0.0000123456');

          final rates = {
            for (final r in await ana.currency.fetchRates()) r.currency: r,
          };
          expect(rates['USD']!.rate, 4012.5);
          expect(rates['EUR']!.rate, closeTo(0.0000123456, 1e-12));
          expect(
            rates['USD']!.updatedAt.difference(DateTime.now()).inMinutes.abs(),
            lessThan(5),
          );
        });

        test('definirla otra vez cambia la tasa y la fecha, sin duplicarla', () async {
          final ana = await newUser('tasas');
          await ana.currency.setRate('USD', '4000');
          final first = (await ana.currency.fetchRates()).single;

          await Future<void>.delayed(const Duration(milliseconds: 20));
          await ana.currency.setRate('USD', '4100');

          final rates = await ana.currency.fetchRates();
          expect(rates, hasLength(1));
          expect(rates.single.rate, 4100);
          expect(rates.single.updatedAt.isAfter(first.updatedAt), isTrue);
        });

        test('se quita una tasa', () async {
          final ana = await newUser('tasas');
          await ana.currency.setRate('USD', '4000');
          await ana.currency.setRate('EUR', '4400');

          await ana.currency.deleteRate('USD');

          expect((await ana.currency.fetchRates()).map((r) => r.currency), ['EUR']);
        });

        test('la moneda base no tiene tasa, con un mensaje que se traduce', () async {
          final ana = await newUser('tasas');
          try {
            await ana.currency.setRate('COP', '1');
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'rate_for_base_currency');
            expect(
              currencyErrorMessage(l10n, error),
              'La moneda base no necesita tasa de cambio',
            );
          }

          // Tampoco la de la base nueva, después de cambiarla.
          await ana.currency.setBaseCurrency('USD');
          await expectLater(
            ana.currency.setRate('USD', '1'),
            failsWith('23514', 'rate_for_base_currency'),
          );
          await ana.currency.setRate('COP', '0.00025'); // la vieja ya es una más
        });

        test('una tasa tiene que ser mayor que cero', () async {
          final ana = await newUser('tasas');
          await expectLater(ana.currency.setRate('USD', '0'), failsWith('23514'));
          await expectLater(ana.currency.setRate('USD', '-4000'), failsWith('23514'));
          expect(await ana.currency.fetchRates(), isEmpty);
        });

        test('el código de la moneda se escribe con tres letras mayúsculas', () async {
          final ana = await newUser('tasas');
          await expectLater(ana.currency.setRate('us', '4000'), throwsA(isA<PostgrestException>()));
          await expectLater(ana.currency.setRate('usd', '4000'), failsWith('23514'));
        });

        test('cada usuario ve solo las suyas', () async {
          final ana = await newUser('ana');
          final beto = await newUser('beto');
          await ana.currency.setRate('USD', '4000');
          await beto.currency.setRate('USD', '3900');

          expect((await ana.currency.fetchRates()).single.rate, 4000);
          expect((await beto.currency.fetchRates()).single.rate, 3900);
        });

        test('sin sesión no se ve nada', () async {
          final anonymous = CurrencyRepository(harness.newClient());
          await expectLater(anonymous.fetchRates(), throwsA(isA<PostgrestException>()));
          await expectLater(anonymous.setRate('USD', '4000'), throwsA(isA<PostgrestException>()));
        });
      });

      group('cambiar la moneda base con tasas y presupuestos', () {
        late String expenseId;

        Future<
          ({
            SupabaseClient client,
            CurrencyRepository currency,
            AccountRepository accounts,
            TransactionRepository transactions,
            BudgetRepository budgets,
            DebtRepository debts,
          })
        >
        withBudget() async {
          final ana = await newUser('rebase');
          expenseId = (await CategoryRepository(ana.client).fetchAll())
              .firstWhere((c) => c.type == CategoryType.expense)
              .id;
          await ana.budgets.set(
            categoryId: expenseId,
            month: DateTime(2026, 10),
            amount: '800000',
          );
          return ana;
        }

        test('reexpresa las tasas: lo que valía en pesos ahora vale en dólares', () async {
          final ana = await newUser('rebase');
          await ana.currency.setRate('USD', '4000');
          await ana.currency.setRate('EUR', '4400');

          await ana.currency.setBaseCurrency('USD');

          final rates = {
            for (final r in await ana.currency.fetchRates()) r.currency: r.rate,
          };
          // 1 EUR = 4.400 COP = 1,1 USD; 1 COP = 0,00025 USD; USD ya es la base.
          expect(rates.keys.toSet(), {'COP', 'EUR'});
          expect(rates['EUR'], closeTo(1.1, 1e-9));
          expect(rates['COP'], closeTo(0.00025, 1e-10));
        });

        test('con la tasa que se da, cuando no estaba guardada', () async {
          final ana = await newUser('rebase');
          await ana.currency.setRate('EUR', '4400');

          await ana.currency.setBaseCurrency('USD', rate: '4000');

          final rates = {
            for (final r in await ana.currency.fetchRates()) r.currency: r.rate,
          };
          expect(rates['EUR'], closeTo(1.1, 1e-9));
          expect(rates['COP'], closeTo(0.00025, 1e-10));
        });

        test('los presupuestos pasan a la moneda nueva', () async {
          final ana = await withBudget();

          await ana.currency.setBaseCurrency('USD', rate: '4000');

          final rule = (await ana.budgets.fetchAll()).single;
          expect(rule.cents, 20000); // $800.000 = US$200
        });

        test('hace falta la tasa cuando hay algo que convertir', () async {
          final ana = await withBudget();

          try {
            await ana.currency.setBaseCurrency('USD');
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(error.code, '23514');
            expect(error.details, 'base_rate_required');
            expect(
              currencyErrorMessage(l10n, error),
              'Hace falta la tasa de la moneda nueva para convertir tus tasas y presupuestos',
            );
          }

          // Nada cambió.
          expect(await ana.currency.fetchBaseCurrency(), 'COP');
          expect((await ana.budgets.fetchAll()).single.cents, 80000000);
        });

        test('y también cuando solo hay tasas', () async {
          final ana = await newUser('rebase');
          await ana.currency.setRate('EUR', '4400');

          await expectLater(
            ana.currency.setBaseCurrency('USD'),
            failsWith('23514', 'base_rate_required'),
          );
          expect(await ana.currency.fetchBaseCurrency(), 'COP');
        });

        test('ir y volver deja todo como estaba', () async {
          final ana = await withBudget();
          await ana.currency.setRate('USD', '4000');

          await ana.currency.setBaseCurrency('USD');
          await ana.currency.setBaseCurrency('COP');

          expect(await ana.currency.fetchBaseCurrency(), 'COP');
          final rates = {
            for (final r in await ana.currency.fetchRates()) r.currency: r.rate,
          };
          expect(rates.keys.toSet(), {'USD'});
          expect(rates['USD'], closeTo(4000, 1e-3));
          expect((await ana.budgets.fetchAll()).single.cents, 80000000);
        });
      });

      group('cuentas en otras monedas', () {
        test('se crea con su moneda y los saldos salen en ella', () async {
          final ana = await newUser('cuentas');
          await ana.accounts.create(
            name: 'Dólares',
            type: AccountType.bank,
            initialBalance: '100.50',
            currency: 'USD',
          );
          await ana.accounts.create(
            name: 'Pesos',
            type: AccountType.cash,
            initialBalance: '1000',
            currency: 'COP',
          );

          final dollars = await accountNamed(ana.accounts, 'Dólares');
          expect(dollars.currency, 'USD');
          expect(dollars.currentBalance, 100.5);
          expect((await accountNamed(ana.accounts, 'Pesos')).currency, 'COP');
        });

        test('editarla no cambia su moneda', () async {
          final ana = await newUser('cuentas');
          await ana.accounts.create(
            name: 'Dólares',
            type: AccountType.bank,
            initialBalance: '10',
            currency: 'USD',
          );
          final account = await accountNamed(ana.accounts, 'Dólares');

          await ana.accounts.update(
            id: account.id,
            name: 'Dólares ahorro',
            type: AccountType.bank,
            initialBalance: '20',
          );

          final edited = await accountNamed(ana.accounts, 'Dólares ahorro');
          expect(edited.currency, 'USD');
          expect(edited.initialBalance, 20);
        });
      });

      group('transferencias entre monedas', () {
        late ({
          SupabaseClient client,
          CurrencyRepository currency,
          AccountRepository accounts,
          TransactionRepository transactions,
          BudgetRepository budgets,
          DebtRepository debts,
        })
        ana;
        late Account pesos;
        late Account otherPesos;
        late Account dollars;

        TransactionDraft transfer(
          Account from,
          Account to,
          String amount, {
          String? destinationAmount,
          DateTime? date,
        }) => TransactionDraft(
          type: TransactionType.transfer,
          accountId: from.id,
          destinationAccountId: to.id,
          amount: amount,
          destinationAmount: destinationAmount,
          date: date ?? DateTime(2026, 10, 10),
        );

        Future<double> balance(Account account) async =>
            (await accountNamed(ana.accounts, account.name)).currentBalance;

        setUpAll(() async {
          ana = await newUser('transfer');
          for (final (name, currency, initial) in [
            ('Pesos', 'COP', '1000000'),
            ('Otros pesos', 'COP', '0'),
            ('Dólares', 'USD', '100'),
          ]) {
            await ana.accounts.create(
              name: name,
              type: AccountType.bank,
              initialBalance: initial,
              currency: currency,
            );
          }
          pesos = await accountNamed(ana.accounts, 'Pesos');
          otherPesos = await accountNamed(ana.accounts, 'Otros pesos');
          dollars = await accountNamed(ana.accounts, 'Dólares');
        });

        test('entre monedas distintas hay que decir cuánto llega', () async {
          await expectLater(
            ana.transactions.create(transfer(pesos, dollars, '400000')),
            failsWith('23514', 'transfer_destination_amount_required'),
          );
          expect(await balance(pesos), 1000000);
        });

        test('el mensaje se traduce y también está en español en la base', () async {
          try {
            await ana.transactions.create(transfer(pesos, dollars, '400000'));
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(
              error.message,
              'Una transferencia entre monedas distintas necesita el monto que llega',
            );
            final english = await loadL10n('en');
            expect(
              currencyErrorMessage(english, error),
              'A transfer between different currencies needs the amount received',
            );
          }
        });

        test('entre la misma moneda no se dice nada de lo que llega', () async {
          await expectLater(
            ana.transactions.create(
              transfer(pesos, otherPesos, '1000', destinationAmount: '1000'),
            ),
            failsWith('23514', 'transfer_destination_amount_unexpected'),
          );
        });

        test('una transferencia entre monedas suma a cada cuenta lo suyo', () async {
          await ana.transactions.create(
            transfer(pesos, dollars, '400000', destinationAmount: '99.50'),
          );

          expect(await balance(pesos), 600000); // salieron $400.000
          expect(await balance(dollars), 199.5); // llegaron US$99,50

          final movement = (await ana.transactions.fetchRecent()).firstWhere(
            (t) => t.type == TransactionType.transfer && t.amount == 400000,
          );
          expect(movement.destinationAmount, 99.5);
        });

        test('no cuenta como ingreso ni gasto', () async {
          final totals = await SummaryRepository(ana.client).fetchMonthlyTotals(
            from: DateTime(2026, 10),
            to: DateTime(2026, 10),
          );
          expect(totals, isEmpty);
        });

        test('el historial mensual de cada cuenta usa lo que llegó', () async {
          final flows = await SummaryRepository(ana.client).fetchAccountFlows();
          final bank = flows.where((f) => f.accountId == pesos.id).toList();
          final usd = flows.where((f) => f.accountId == dollars.id).toList();

          expect(bank.single.currency, 'COP');
          expect(bank.single.cents, -40000000);
          expect(usd.single.currency, 'USD');
          expect(usd.single.cents, 9950);
        });

        test('se puede corregir lo que llegó y los saldos siguen', () async {
          final movement = (await ana.transactions.fetchRecent()).firstWhere(
            (t) => t.type == TransactionType.transfer && t.amount == 400000,
          );

          await ana.transactions.update(
            movement.id,
            transfer(pesos, dollars, '400000', destinationAmount: '100'),
          );

          expect(await balance(dollars), 200);
          expect(await balance(pesos), 600000);
        });

        test('al borrarla, cada cuenta recupera lo suyo', () async {
          final movement = (await ana.transactions.fetchRecent()).firstWhere(
            (t) => t.type == TransactionType.transfer && t.amount == 400000,
          );

          await ana.transactions.delete(movement.id);

          expect(await balance(pesos), 1000000);
          expect(await balance(dollars), 100);
        });

        test('lo que llega tiene que ser positivo', () async {
          await expectLater(
            ana.transactions.create(
              transfer(pesos, dollars, '1000', destinationAmount: '0'),
            ),
            failsWith('23514'),
          );
          await expectLater(
            ana.transactions.create(
              transfer(pesos, dollars, '1000', destinationAmount: '-1'),
            ),
            failsWith('23514'),
          );
        });

        test('un ingreso o un gasto no pueden traer "lo que llega"', () async {
          await expectLater(
            ana.client.from('transactions').insert({
              'type': 'expense',
              'account_id': pesos.id,
              'amount': '100',
              'destination_amount': '5',
              'transaction_date': '2026-10-10',
            }),
            failsWith('23514'),
          );
        });

        test('pasar de transferencia a gasto borra lo que llegaba', () async {
          await ana.transactions.create(
            transfer(pesos, dollars, '10000', destinationAmount: '2.5', date: DateTime(2026, 9, 1)),
          );
          final movement = (await ana.transactions.fetchRecent()).firstWhere(
            (t) => t.type == TransactionType.transfer && t.amount == 10000,
          );

          await ana.transactions.update(
            movement.id,
            TransactionDraft(
              type: TransactionType.expense,
              accountId: pesos.id,
              amount: '10000',
              date: DateTime(2026, 9, 1),
            ),
          );

          final edited = (await ana.transactions.fetchRecent()).firstWhere((t) => t.id == movement.id);
          expect(edited.type, TransactionType.expense);
          expect(edited.destinationAmount, isNull);
        });

        test('otro usuario no ve ni toca estos movimientos', () async {
          final beto = await newUser('beto');
          expect(await beto.transactions.fetchRecent(), isEmpty);
        });
      });

      group('totales por moneda', () {
        test('cada fila de los totales mensuales trae la moneda de su cuenta', () async {
          final ana = await newUser('totales');
          final categories = await CategoryRepository(ana.client).fetchAll();
          final food = categories.firstWhere((c) => c.type == CategoryType.expense);
          await ana.accounts.create(
            name: 'Pesos',
            type: AccountType.bank,
            initialBalance: '1000000',
            currency: 'COP',
          );
          await ana.accounts.create(
            name: 'Dólares',
            type: AccountType.bank,
            initialBalance: '1000',
            currency: 'USD',
          );
          final pesos = await accountNamed(ana.accounts, 'Pesos');
          final dollars = await accountNamed(ana.accounts, 'Dólares');
          for (final (account, amount) in [(pesos, '50000'), (dollars, '12.50')]) {
            await ana.transactions.create(
              TransactionDraft(
                type: TransactionType.expense,
                accountId: account.id,
                categoryId: food.id,
                amount: amount,
                date: DateTime(2026, 10, 5),
              ),
            );
          }

          final totals = await SummaryRepository(ana.client).fetchMonthlyTotals(
            from: DateTime(2026, 10),
            to: DateTime(2026, 10),
          );

          final byCurrency = {for (final t in totals) t.currency: t.total};
          expect(byCurrency, {'COP': 50000, 'USD': 12.5});
        });
      });

      group('deudas en otras monedas', () {
        DebtDraft draft(
          String name, {
          String amount = '100',
          String? currency,
          Account? account,
        }) => DebtDraft(
          direction: DebtDirection.payable,
          counterparty: name,
          amount: amount,
          startDate: DateTime(2026, 10, 1),
          accountId: account?.id,
          currency: currency,
        );

        test('sin cuenta, es en la moneda que se diga', () async {
          final ana = await newUser('deudas');
          await ana.debts.create(draft('Luis', currency: 'USD'));

          expect((await ana.debts.fetchAll()).single.currency, 'USD');
        });

        test('sin cuenta ni moneda, es en la moneda base', () async {
          final ana = await newUser('deudas');
          await ana.debts.create(draft('Ana'));
          await ana.currency.setBaseCurrency('EUR');
          await ana.debts.create(draft('Beto'));

          final currencies = {
            for (final d in await ana.debts.fetchAll()) d.counterparty: d.currency,
          };
          expect(currencies, {'Ana': 'COP', 'Beto': 'EUR'});
        });

        test('con cuenta, es en la moneda de la cuenta (aunque se diga otra)', () async {
          final ana = await newUser('deudas');
          await ana.accounts.create(
            name: 'Dólares',
            type: AccountType.bank,
            initialBalance: '0',
            currency: 'USD',
          );
          final dollars = await accountNamed(ana.accounts, 'Dólares');

          await ana.debts.create(draft('Luis', currency: 'EUR', account: dollars));

          final debt = (await ana.debts.fetchAll()).single;
          expect(debt.currency, 'USD');
          expect((await accountNamed(ana.accounts, 'Dólares')).currentBalance, 100);
        });

        test('un abono tiene que ser de una cuenta en la moneda de la deuda', () async {
          final ana = await newUser('deudas');
          await ana.accounts.create(
            name: 'Pesos',
            type: AccountType.bank,
            initialBalance: '1000000',
            currency: 'COP',
          );
          final pesos = await accountNamed(ana.accounts, 'Pesos');
          await ana.debts.create(draft('Luis', currency: 'USD'));
          final debt = (await ana.debts.fetchAll()).single;

          await expectLater(
            ana.debts.registerPayment(
              debtId: debt.id,
              accountId: pesos.id,
              amount: '10',
              date: DateTime(2026, 10, 20),
            ),
            failsWith('23514', 'payment_currency_mismatch'),
          );
        });
      });
    },
  );
}
