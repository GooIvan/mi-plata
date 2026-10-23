import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime _today() => DateTime(_now.year, _now.month, _now.day);
DateTime _thisMonth() => DateTime(_now.year, _now.month);

ExchangeRate rate(String currency, double value) =>
    ExchangeRate(currency: currency, rate: value, updatedAt: DateTime.now());

Future<FakeBackend> open(
  WidgetTester tester,
  FakeBackend backend, {
  String? route,
  String language = 'es',
}) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpMiPlata(tester, backend: backend, language: language);
  if (route != null) await goTo(tester, route);
  return backend;
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);
Finder dropdown(int index) => find.byType(DropdownButtonFormField<String>).at(index);

Future<void> pick(WidgetTester tester, Finder from, String option) async {
  await tester.tap(from);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Pesos (1.000.000), dólares (100) y euros (50), con el dólar a $4.000.
FakeBackend threeCurrencies({List<ExchangeRate>? rates}) =>
    FakeBackend(
      accounts: [
        testAccount('Bancolombia', balance: 1000000),
        testAccount('Dólares', balance: 100, currency: 'USD'),
        testAccount('Euros', balance: 50, currency: 'EUR'),
      ],
      categories: [
        testCategory('Mercado', CategoryType.expense),
        testCategory('Salario', CategoryType.income),
      ],
      rates: rates ?? [rate('USD', 4000), rate('EUR', 4400)],
    );

void main() {
  setUpAll(initDates);

  group('el panel', () {
    testWidgets('suma todo en la moneda base y muestra cada moneda aparte', (tester) async {
      await open(tester, threeCurrencies());

      // 1.000.000 + 100 * 4.000 + 50 * 4.400 = 1.620.000
      expect(textLike(r'$1.620.000'), findsOneWidget);
      expect(find.text('En 3 cuentas'), findsOneWidget);
      // Lo que hay en cada moneda, tal cual, debajo del total y en la lista.
      expect(textLike(r'US$100'), findsWidgets);
      expect(textLike('€50'), findsWidgets);
      expect(find.textContaining('Sin tasa de cambio'), findsNothing);
    });

    testWidgets('una moneda sin tasa no suma y avisa, con un atajo para definirla', (
      tester,
    ) async {
      await open(tester, threeCurrencies(rates: [rate('USD', 4000)]));

      expect(textLike(r'$1.400.000'), findsOneWidget); // sin los euros
      expect(find.textContaining('Sin tasa de cambio para EUR'), findsOneWidget);

      await tester.tap(find.text('Definir'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Tasas de cambio'), findsOneWidget);
    });

    testWidgets('con otra moneda base, el total sale en ella', (tester) async {
      await open(
        tester,
        FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 400000),
            testAccount('Dólares', balance: 100, currency: 'USD'),
          ],
          baseCurrency: 'USD',
          rates: [rate('COP', 0.00025)],
        ),
      );

      expect(textLike(r'US$200'), findsOneWidget); // US$100 + $400.000 = US$200
    });

    testWidgets('una cuenta en dólares sin tasa: total en cero y aviso', (tester) async {
      await open(
        tester,
        FakeBackend(accounts: [testAccount('Dólares', balance: 100, currency: 'USD')]),
      );

      expect(textLike(r'$0'), findsOneWidget);
      expect(find.textContaining('Sin tasa de cambio para USD'), findsOneWidget);
    });

    testWidgets('los movimientos y las cuentas salen en su moneda', (tester) async {
      final backend = threeCurrencies();
      await open(tester, backend);

      expect(textLike(r'US$100'), findsWidgets);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), '10');
      await pick(tester, dropdown(0), 'Dólares · USD');
      // El monto va en la moneda de la cuenta elegida.
      expect(find.text(r'US$ '), findsOneWidget);
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      // El gasto de US$10 sale con su símbolo y baja la cuenta.
      expect(find.text(r'-US$10'), findsOneWidget);
      expect(textLike(r'US$90'), findsWidgets);
    });
  });

  group('transferencias entre monedas', () {
    Future<void> openTransfer(WidgetTester tester, FakeBackend backend) async {
      await open(tester, backend);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<TransactionType>),
        matching: find.text('Transferencia'),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('entre la misma moneda no pide un segundo monto', (tester) async {
      final backend = FakeBackend(accounts: [
        testAccount('A', balance: 1000),
        testAccount('B', balance: 0),
      ]);
      await openTransfer(tester, backend);

      await tester.enterText(field(0), '500');
      await pick(tester, dropdown(0), 'A');
      await pick(tester, dropdown(1), 'B');

      expect(find.byType(TextFormField), findsNWidgets(2)); // monto y descripción
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.created.single;
      expect(draft.destinationAmount, isNull);
    });

    testWidgets('entre monedas distintas pide lo que llega y muestra la tasa', (tester) async {
      final backend = threeCurrencies();
      await openTransfer(tester, backend);

      await tester.enterText(field(0), '400.000');
      await pick(tester, dropdown(0), 'Bancolombia');
      await pick(tester, dropdown(1), 'Dólares · USD');

      expect(find.text('Monto que sale (COP)'), findsOneWidget);
      expect(find.text('Monto que llega (USD)'), findsOneWidget);

      await tester.enterText(field(1), '99,5');
      await tester.pump();
      // Salen $400.000 y llegan US$99,50: 1 COP = 0,000249 USD.
      expect(find.text('1 COP = 0,000249 USD'), findsOneWidget);

      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.created.single;
      expect(draft.amount, '400000');
      expect(draft.destinationAmount, '99.5');

      // Los saldos suman lo que llegó, no lo que salió: $600.000 y US$199,50.
      final balances = {
        for (final a in await backend.accounts.fetchAll()) a.name: a.currentBalance,
      };
      expect(balances['Bancolombia'], 600000);
      expect(balances['Dólares'], 199.5);
    });

    testWidgets('lo que llega es obligatorio', (tester) async {
      final backend = threeCurrencies();
      await openTransfer(tester, backend);

      await tester.enterText(field(0), '400.000');
      await pick(tester, dropdown(0), 'Bancolombia');
      await pick(tester, dropdown(1), 'Dólares · USD');
      await tester.tap(button('Registrar'));
      await tester.pump();

      expect(find.text('Ingresa el monto'), findsOneWidget);
      expect(backend.transactions.created, isEmpty);
    });

    testWidgets('si se cambia el destino a la misma moneda, ya no se manda', (tester) async {
      final backend = FakeBackend(accounts: [
        testAccount('Pesos', balance: 1000000),
        testAccount('Otra', balance: 0),
        testAccount('Dólares', balance: 10, currency: 'USD'),
      ]);
      await openTransfer(tester, backend);

      await tester.enterText(field(0), '1.000');
      await pick(tester, dropdown(0), 'Pesos');
      await pick(tester, dropdown(1), 'Dólares · USD');
      await tester.enterText(field(1), '0,25');
      await pick(tester, dropdown(1), 'Otra');

      expect(find.textContaining('Monto que llega'), findsNothing);
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();
      expect(backend.transactions.created.single.destinationAmount, isNull);
    });

    testWidgets('el aviso de saldo negativo usa la moneda de cada cuenta', (tester) async {
      final backend = FakeBackend(
        accounts: [
          testAccount('Dólares', balance: 10, currency: 'USD'),
          testAccount('Pesos', balance: 0),
        ],
        rates: [rate('USD', 4000)],
      );
      await openTransfer(tester, backend);

      await tester.enterText(field(0), '25');
      await pick(tester, dropdown(0), 'Dólares · USD');
      await pick(tester, dropdown(1), 'Pesos');
      await tester.enterText(field(1), '100.000');
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Registrar de todos modos?'), findsOneWidget);
      expect(find.textContaining(r'Dólares quedará en -US$15.'), findsOneWidget);
    });

    testWidgets('editar una transferencia entre monedas precarga los dos montos', (tester) async {
      final backend = FakeBackend(
        accounts: [
          testAccount('Pesos', balance: 1000000),
          testAccount('Dólares', balance: 0, currency: 'USD'),
        ],
        transactions: [
          testTransaction(
            't1',
            type: TransactionType.transfer,
            accountId: 'id-Pesos',
            destinationAccountId: 'id-Dólares',
            amount: 400000,
            destinationAmount: 99.5,
            date: _today(),
          ),
        ],
      );
      await open(tester, backend, route: AppRoutes.transactions);

      await tester.tap(find.textContaining('Pesos → Dólares'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(field(0)).controller?.text, '400000');
      expect(tester.widget<TextFormField>(field(1)).controller?.text, '99,50');

      await tester.enterText(field(1), '100');
      await tester.tap(button('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(backend.transactions.updated['t1']!.destinationAmount, '100');
    });

    testWidgets('la lista muestra lo que salió y lo que llegó', (tester) async {
      final backend = FakeBackend(
        accounts: [
          testAccount('Pesos', balance: 1000000),
          testAccount('Dólares', balance: 0, currency: 'USD'),
        ],
        transactions: [
          testTransaction(
            't1',
            type: TransactionType.transfer,
            accountId: 'id-Pesos',
            destinationAccountId: 'id-Dólares',
            amount: 400000,
            destinationAmount: 99.5,
            date: _today(),
          ),
        ],
      );
      await open(tester, backend, route: AppRoutes.transactions);

      expect(textLike(r'$400.000'), findsOneWidget);
      expect(find.text(r'Pesos → Dólares · recibe US$99,50'), findsOneWidget);
    });
  });

  group('el resumen', () {
    FakeBackend withExpenses({List<ExchangeRate>? rates}) {
      return FakeBackend(
        accounts: [
          testAccount('Bancolombia', balance: 1000000),
          testAccount('Dólares', balance: 100, currency: 'USD'),
        ],
        categories: [testCategory('Mercado', CategoryType.expense)],
        transactions: [
          testTransaction('t1',
              type: TransactionType.expense,
              accountId: 'id-Bancolombia',
              categoryId: 'cat-Mercado',
              amount: 100000,
              date: _today()),
          testTransaction('t2',
              type: TransactionType.expense,
              accountId: 'id-Dólares',
              categoryId: 'cat-Mercado',
              amount: 10,
              date: _today()),
        ],
        rates: rates ?? [rate('USD', 4000)],
      );
    }

    testWidgets('los gastos de otra moneda se suman convertidos', (tester) async {
      await open(tester, withExpenses(), route: AppRoutes.summary);

      // $100.000 + US$10 a $4.000 = $140.000.
      expect(find.text('Gastos'), findsWidgets);
      expect(textLike(r'$140.000'), findsWidgets);
      expect(find.textContaining('Sin tasa de cambio'), findsNothing);
      // El gráfico de evolución avisa que convierte con la tasa de hoy.
      expect(find.text('Los montos en otras monedas se pasan a COP con la tasa de hoy.'), findsOneWidget);
    });

    testWidgets('sin tasa, esos gastos no se suman y se avisa arriba', (tester) async {
      await open(tester, withExpenses(rates: const []), route: AppRoutes.summary);

      expect(textLike(r'$100.000'), findsWidgets);
      expect(find.textContaining('Sin tasa de cambio para USD'), findsWidgets);
    });

    testWidgets('en inglés y con otra base', (tester) async {
      await open(
        tester,
        FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 1000000),
            testAccount('Dólares', balance: 100, currency: 'USD'),
          ],
          categories: [testCategory('Mercado', CategoryType.expense)],
          transactions: [
            testTransaction('t1',
                type: TransactionType.expense,
                accountId: 'id-Bancolombia',
                categoryId: 'cat-Mercado',
                amount: 400000,
                date: _today()),
          ],
          baseCurrency: 'USD',
          rates: [rate('COP', 0.00025)],
        ),
        route: AppRoutes.summary,
        language: 'en',
      );

      expect(textLike(r'US$100'), findsWidgets); // $400.000 = US$100
    });
  });

  group('los presupuestos', () {
    FakeBackend budgeted({List<ExchangeRate>? rates}) => FakeBackend(
      accounts: [
        testAccount('Bancolombia', balance: 1000000),
        testAccount('Dólares', balance: 100, currency: 'USD'),
      ],
      categories: [testCategory('Mercado', CategoryType.expense)],
      transactions: [
        testTransaction('t1',
            type: TransactionType.expense,
            accountId: 'id-Bancolombia',
            categoryId: 'cat-Mercado',
            amount: 100000,
            date: _today()),
        testTransaction('t2',
            type: TransactionType.expense,
            accountId: 'id-Dólares',
            categoryId: 'cat-Mercado',
            amount: 10,
            date: _today()),
      ],
      budgets: [
        BudgetRule(
          id: 'r1',
          categoryId: 'cat-Mercado',
          month: _thisMonth(),
          cents: 20000000,
        ),
      ],
      rates: rates ?? [rate('USD', 4000)],
    );

    testWidgets('un gasto en dólares cuenta contra el presupuesto en pesos', (tester) async {
      await open(tester, budgeted(), route: AppRoutes.budgets);

      // $100.000 + US$10 a $4.000 = $140.000 de $200.000.
      expect(find.text(r'$140.000'), findsWidgets);
      expect(find.textContaining(r'de $200.000'), findsWidgets);
      expect(find.text('70 %'), findsWidgets);
    });

    testWidgets('sin tasa, lo gastado en esa moneda se aparta y se avisa', (tester) async {
      await open(tester, budgeted(rates: const []), route: AppRoutes.budgets);

      expect(find.text(r'$100.000'), findsWidgets);
      expect(find.textContaining('Sin tasa de cambio para USD'), findsOneWidget);
    });

    testWidgets('el formulario muestra la moneda base', (tester) async {
      await open(
        tester,
        FakeBackend(baseCurrency: 'USD', categories: [testCategory('Mercado', CategoryType.expense)]),
        route: AppRoutes.budgets,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text(r'US$ '), findsOneWidget);
    });

    testWidgets('el aviso al registrar convierte el gasto de otra moneda', (tester) async {
      // El presupuesto es de $200.000 y ya se llevan $100.000: un gasto de US$20
      // ($80.000) lo deja en $180.000, el 90 %.
      final backend = FakeBackend(
        accounts: [
          testAccount('Bancolombia', balance: 1000000),
          testAccount('Dólares', balance: 100, currency: 'USD'),
        ],
        categories: [testCategory('Mercado', CategoryType.expense)],
        transactions: [
          testTransaction('t1',
              type: TransactionType.expense,
              accountId: 'id-Bancolombia',
              categoryId: 'cat-Mercado',
              amount: 100000,
              date: _today()),
        ],
        budgets: [
          BudgetRule(
            id: 'r1',
            categoryId: 'cat-Mercado',
            month: _thisMonth(),
            cents: 20000000,
          ),
        ],
        rates: [rate('USD', 4000)],
      );
      await open(tester, backend);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), '20');
      await pick(tester, dropdown(0), 'Dólares · USD');
      await pick(tester, find.byType(DropdownButtonFormField<String?>), 'Mercado');
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(r'Vas en 90 % del presupuesto de Mercado ($180.000 de $200.000).'),
        findsOneWidget,
      );
    });

    testWidgets('sin tasa para el gasto no hay aviso, pero se guarda', (tester) async {
      final backend = FakeBackend(
        accounts: [
          testAccount('Dólares', balance: 100, currency: 'USD'),
        ],
        categories: [testCategory('Mercado', CategoryType.expense)],
        budgets: [
          BudgetRule(
            id: 'r1',
            categoryId: 'cat-Mercado',
            month: _thisMonth(),
            cents: 100000,
          ),
        ],
      );
      await open(tester, backend);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), '50');
      await pick(tester, dropdown(0), 'Dólares · USD');
      await pick(tester, find.byType(DropdownButtonFormField<String?>), 'Mercado');
      await tester.tap(button('Registrar'));
      await tester.pumpAndSettle();

      expect(backend.transactions.created, hasLength(1));
      expect(find.textContaining('presupuesto de Mercado'), findsNothing);
    });
  });

  group('las deudas', () {
    testWidgets('los totales suman las deudas de otras monedas convertidas', (tester) async {
      final backend = FakeBackend(
        accounts: [testAccount('Bancolombia', balance: 1000000)],
        rates: [rate('USD', 4000)],
      );
      backend.debts
        ..seedDebt(counterparty: 'Juan', amount: 100000)
        ..seedDebt(counterparty: 'Ana', amount: 50, currency: 'USD')
        ..seedDebt(counterparty: 'Luis', amount: 20, currency: 'EUR');
      await open(tester, backend, route: AppRoutes.debts);

      // $100.000 + US$50 a $4.000 = $300.000; los euros no tienen tasa.
      expect(find.text('Debes en total'), findsOneWidget);
      expect(find.text(r'$300.000'), findsOneWidget);
      expect(find.textContaining('Sin tasa de cambio para EUR'), findsOneWidget);
      // Cada deuda, en su moneda.
      expect(find.text(r'US$50'), findsOneWidget);
      expect(find.text('€20'), findsOneWidget);
    });

    testWidgets('la tarjeta del panel suma lo que debes y lo que te deben', (tester) async {
      final backend = FakeBackend(
        accounts: [testAccount('Bancolombia', balance: 1000000)],
        rates: [rate('USD', 4000)],
      );
      backend.debts
        ..seedDebt(counterparty: 'Ana', amount: 50, currency: 'USD')
        ..seedDebt(
          direction: DebtDirection.receivable,
          counterparty: 'María',
          amount: 300000,
        );
      await open(tester, backend);

      expect(find.text('Debes'), findsOneWidget);
      expect(find.text(r'$200.000'), findsOneWidget); // US$50 a $4.000
      expect(find.text(r'$300.000'), findsOneWidget);
    });

    testWidgets('una deuda nueva sin cuenta se crea en la moneda elegida', (tester) async {
      final backend = FakeBackend(accounts: [testAccount('Bancolombia', balance: 1000)]);
      await open(tester, backend, route: AppRoutes.debts);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva deuda'));
      await tester.pumpAndSettle();
      // Por defecto, la moneda base.
      expect(find.text('COP · Peso colombiano'), findsOneWidget);
      await pick(tester, dropdown(0), 'USD · Dólar estadounidense');
      await tester.enterText(field(0), 'Luis');
      await tester.enterText(field(1), '50');
      expect(find.text(r'US$ '), findsOneWidget);
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(find.text(r'US$50'), findsOneWidget);
      expect((await backend.debts.fetchAll()).single.currency, 'USD');
    });

    testWidgets('con el dinero en una cuenta, la deuda es en la moneda de la cuenta', (
      tester,
    ) async {
      final backend = FakeBackend(accounts: [
        testAccount('Bancolombia', balance: 1000),
        testAccount('Dólares', balance: 5, currency: 'USD'),
      ]);
      await open(tester, backend, route: AppRoutes.debts);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva deuda'));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'Luis');
      await tester.enterText(field(1), '50');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Ya no se ofrece elegir la moneda: sale de la cuenta.
      expect(find.text('COP · Peso colombiano'), findsNothing);
      await pick(tester, dropdown(0), 'Dólares · USD');
      expect(find.text(r'US$ '), findsOneWidget);
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      final debt = (await backend.debts.fetchAll()).single;
      expect(debt.currency, 'USD');
      expect(
        backend.transactions.transactions.any((t) => t.accountId == 'id-Dólares' && t.amount == 50),
        isTrue,
      );
    });

    testWidgets('el abono usa la moneda de la deuda', (tester) async {
      final backend = FakeBackend(accounts: [
        testAccount('Bancolombia', balance: 1000),
        testAccount('Dólares', balance: 500, currency: 'USD'),
      ]);
      backend.debts.seedDebt(
        counterparty: 'Ana',
        amount: 100,
        currency: 'USD',
        accountId: 'id-Dólares',
      );
      await open(tester, backend, route: AppRoutes.debts);

      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text(r'Pendiente: US$100'), findsOneWidget);
      expect(find.text(r'US$ '), findsOneWidget);
      // Solo se ofrecen cuentas en dólares.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Bancolombia'), findsNothing);
      expect(find.text('Dólares · USD'), findsWidgets);
    });
  });

  group('en inglés', () {
    testWidgets('el panel y las tasas', (tester) async {
      await open(tester, threeCurrencies(rates: [rate('USD', 4000)]), language: 'en');

      expect(find.text('Total money'), findsOneWidget);
      expect(find.textContaining('No exchange rate for EUR'), findsOneWidget);
      expect(find.text('Set rate'), findsOneWidget);

      await tester.tap(find.text('Set rate'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Exchange rates'), findsOneWidget);
      expect(find.text('No rate'), findsOneWidget);
      expect(find.textContaining(r'1 USD = $4,000'), findsOneWidget);
    });
  });
}
