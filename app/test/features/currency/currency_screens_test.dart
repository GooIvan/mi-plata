import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

ExchangeRate rate(String currency, double value, {DateTime? updatedAt}) =>
    ExchangeRate(
      currency: currency,
      rate: value,
      updatedAt: updatedAt ?? DateTime.now(),
    );

Future<void> tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeBackend> open(
  WidgetTester tester,
  FakeBackend backend, {
  String? route,
  String language = 'es',
}) async {
  await tall(tester);
  await pumpMiPlata(tester, backend: backend, language: language);
  if (route != null) await goTo(tester, route);
  return backend;
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);

/// Elige una opción de un desplegable.
Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initDates);

  group('ajustes de moneda', () {
    testWidgets('muestran la moneda base y llevan a las tasas', (tester) async {
      await open(tester, FakeBackend(), route: AppRoutes.settings);

      expect(find.text('Moneda base'), findsOneWidget);
      expect(find.text('COP · Peso colombiano'), findsOneWidget);
      expect(find.text('Tasas de cambio'), findsOneWidget);

      await tester.tap(find.text('Tasas de cambio'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Tasas de cambio'), findsOneWidget);
    });

    testWidgets('en inglés', (tester) async {
      await open(tester, FakeBackend(baseCurrency: 'USD'),
          route: AppRoutes.settings, language: 'en');

      expect(find.text('Base currency'), findsOneWidget);
      expect(find.text('USD · US dollar'), findsOneWidget);
      expect(find.text('Exchange rates'), findsOneWidget);
    });
  });

  group('cambiar la moneda base', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Moneda base'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin tasas ni presupuestos basta con elegirla', (tester) async {
      final backend = await open(tester, FakeBackend(), route: AppRoutes.settings);
      await openSheet(tester);
      expect(tester.widget<FilledButton>(button('Cambiar moneda base')).onPressed, isNull);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('setBase:USD:'));
      expect(backend.currency.base, 'USD');
      expect(find.text('USD · Dólar estadounidense'), findsOneWidget);
    });

    testWidgets('con una tasa se reexpresan las demás en la moneda nueva', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(rates: [rate('USD', 4000), rate('EUR', 4400)]),
        route: AppRoutes.settings,
      );
      await openSheet(tester);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      // La tasa guardada del dólar aparece lista.
      expect(find.text('1 USD vale (COP)'), findsOneWidget);
      expect(tester.widget<TextFormField>(field(0)).controller?.text, '4000');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pumpAndSettle();

      expect(backend.currency.base, 'USD');
      // 1 EUR = 4.400 COP = 1,1 USD; 1 COP = 0,00025 USD; el dólar ya no tiene tasa.
      expect(backend.currency.rates['EUR']!.rate, closeTo(1.1, 1e-9));
      expect(backend.currency.rates['COP']!.rate, closeTo(0.00025, 1e-12));
      expect(backend.currency.rates.containsKey('USD'), isFalse);
    });

    testWidgets('los presupuestos se pasan a la moneda nueva', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(
          budgets: [
            BudgetRule(
              id: 'r1',
              categoryId: 'cat-Mercado',
              month: DateTime(2026, 10),
              cents: 80000000,
            ),
          ],
        ),
        route: AppRoutes.settings,
      );
      await openSheet(tester);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.enterText(field(0), '4.000');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('setBase:USD:4000'));
      expect(backend.budgets.rules.single.cents, 20000); // $800.000 = US$200
    });

    testWidgets('si hace falta la tasa y no se da, lo explica', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(rates: [rate('EUR', 4400)]),
        route: AppRoutes.settings,
      );
      await openSheet(tester);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hace falta la tasa de la moneda nueva para convertir tus tasas y presupuestos'),
        findsOneWidget,
      );
      expect(backend.currency.base, 'COP'); // no cambió nada
      expect(find.byType(BottomSheet), findsOneWidget); // y la hoja sigue abierta
    });

    testWidgets('una tasa mal escrita no se envía', (tester) async {
      final backend = await open(tester, FakeBackend(), route: AppRoutes.settings);
      await openSheet(tester);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.enterText(field(0), 'mucho');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pump();

      expect(find.text('Escribe una tasa mayor que cero. Ejemplo: 4.012,5'), findsOneWidget);
      expect(backend.currency.calls.where((c) => c.startsWith('setBase')), isEmpty);
    });

    testWidgets('si el servidor falla, avisa y no cambia', (tester) async {
      final backend = await open(tester, FakeBackend(), route: AppRoutes.settings);
      await openSheet(tester);
      backend.currency.error = const PostgrestException(message: 'x', code: 'PGRST301');

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'EUR · Euro');
      await tester.tap(button('Cambiar moneda base'));
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión expiró. Vuelve a iniciar sesión.'), findsOneWidget);
    });
  });

  group('tasas de cambio', () {
    testWidgets('lista las monedas en uso, las que faltan primero', (tester) async {
      await open(
        tester,
        FakeBackend(
          accounts: [
            testAccount('Banco', balance: 100000),
            testAccount('Dólares', balance: 50, currency: 'USD'),
            testAccount('Euros', balance: 20, currency: 'EUR'),
            testAccount('Vieja', balance: 1, currency: 'MXN', archived: true),
          ],
          rates: [rate('USD', 4000)],
        ),
        route: AppRoutes.rates,
      );

      expect(find.text('Para sumar el dinero de tus cuentas en otras monedas, define cuánto vale cada una en COP. Los totales usan la tasa de hoy.'), findsOneWidget);
      expect(find.text('EUR · Euro'), findsOneWidget);
      expect(find.text('USD · Dólar estadounidense'), findsOneWidget);
      expect(find.text('MXN · Peso mexicano'), findsNothing); // archivada
      expect(find.text('Sin tasa'), findsOneWidget);
      expect(find.textContaining(r'1 USD = $4.000'), findsOneWidget);
      expect(find.text('COP · Peso colombiano'), findsNothing);

      // Sin tasa primero.
      final eur = tester.getTopLeft(find.text('EUR · Euro')).dy;
      final usd = tester.getTopLeft(find.text('USD · Dólar estadounidense')).dy;
      expect(eur, lessThan(usd));
    });

    testWidgets('sin monedas en uso lo dice', (tester) async {
      await open(tester, FakeBackend(accounts: [testAccount('Banco')]), route: AppRoutes.rates);

      expect(find.textContaining('No tienes cuentas ni deudas en otras monedas'), findsOneWidget);
    });

    testWidgets('también salen las monedas de las deudas', (tester) async {
      final backend = FakeBackend(accounts: [testAccount('Banco', balance: 1000)]);
      backend.debts.seedDebt(counterparty: 'Ana', amount: 100, currency: 'EUR');
      await open(tester, backend, route: AppRoutes.rates);

      expect(find.text('EUR · Euro'), findsOneWidget);
    });

    testWidgets('define la tasa de una moneda', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(accounts: [testAccount('Dólares', balance: 50, currency: 'USD')]),
        route: AppRoutes.rates,
      );

      await tester.tap(find.text('USD · Dólar estadounidense'));
      await tester.pumpAndSettle();
      expect(find.text('Tasa de USD'), findsOneWidget);
      expect(find.text('1 USD vale'), findsOneWidget);
      await tester.enterText(field(0), '4.012,5');
      await tester.tap(button('Guardar'));
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('setRate:USD:4012.5'));
      expect(find.textContaining(r'1 USD = $4.012,50'), findsOneWidget);
      expect(find.textContaining('Actualizada hoy'), findsOneWidget);
      expect(find.text('Sin tasa'), findsNothing);
    });

    testWidgets('cambia una tasa que ya existe, y la muestra precargada', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(
          accounts: [testAccount('Dólares', balance: 50, currency: 'USD')],
          rates: [rate('USD', 4000, updatedAt: DateTime.now().subtract(const Duration(days: 3)))],
        ),
        route: AppRoutes.rates,
      );
      expect(find.textContaining('Actualizada hace 3 días'), findsOneWidget);

      await tester.tap(find.text('USD · Dólar estadounidense'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field(0)).controller?.text, '4000');
      await tester.enterText(field(0), '4.100');
      await tester.tap(button('Guardar'));
      await tester.pumpAndSettle();

      expect(backend.currency.rates['USD']!.rate, 4100);
      expect(find.textContaining('Actualizada hoy'), findsOneWidget);
    });

    testWidgets('quita una tasa', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(
          accounts: [testAccount('Dólares', balance: 50, currency: 'USD')],
          rates: [rate('USD', 4000)],
        ),
        route: AppRoutes.rates,
      );

      await tester.tap(find.text('USD · Dólar estadounidense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar la tasa'));
      await tester.pumpAndSettle();

      expect(backend.currency.rates, isEmpty);
      expect(find.text('Sin tasa'), findsOneWidget);
    });

    testWidgets('una tasa inválida no se envía', (tester) async {
      final backend = await open(
        tester,
        FakeBackend(accounts: [testAccount('Dólares', balance: 50, currency: 'USD')]),
        route: AppRoutes.rates,
      );
      await tester.tap(find.text('USD · Dólar estadounidense'));
      await tester.pumpAndSettle();

      for (final input in ['', '0', '-3', 'abc']) {
        await tester.enterText(field(0), input);
        await tester.tap(button('Guardar'));
        await tester.pump();
        expect(find.text('Escribe una tasa mayor que cero. Ejemplo: 4.012,5'), findsOneWidget,
            reason: 'entrada "$input"');
      }
      expect(backend.currency.calls.where((c) => c.startsWith('setRate')), isEmpty);
    });

    testWidgets('agregar una tasa de una moneda que aún no se usa', (tester) async {
      final backend = await open(tester, FakeBackend(), route: AppRoutes.rates);

      await tester.tap(find.text('Agregar tasa'));
      await tester.pumpAndSettle();
      // La moneda base no se ofrece.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('COP · Peso colombiano'), findsNothing);
      await tester.tap(find.text('GBP · Libra esterlina').last);
      await tester.pumpAndSettle();
      await tester.enterText(field(0), '5.000');
      await tester.tap(button('Guardar'));
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('setRate:GBP:5000'));
      expect(find.text('GBP · Libra esterlina'), findsOneWidget);
    });

    testWidgets('agregar sin elegir moneda pide elegirla', (tester) async {
      await open(tester, FakeBackend(), route: AppRoutes.rates);

      await tester.tap(find.text('Agregar tasa'));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), '5000');
      await tester.tap(button('Guardar'));
      await tester.pump();

      expect(find.text('Elige una moneda'), findsOneWidget);
    });

    testWidgets('si falla la carga, ofrece reintentar', (tester) async {
      final backend = FakeBackend()..currency.error = Exception('boom');
      await open(tester, backend, route: AppRoutes.rates);

      expect(find.text('Reintentar'), findsOneWidget);
      backend.currency.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('crear una cuenta en otra moneda', () {
    Future<void> openForm(WidgetTester tester, FakeBackend backend) async {
      await open(tester, backend, route: AppRoutes.accounts);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWidgets('en pesos no pide moneda ni tasa', (tester) async {
      final backend = FakeBackend();
      await openForm(tester, backend);

      await tester.enterText(field(0), 'Banco');
      await tester.enterText(field(1), '1.000');
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(backend.accounts.calls, contains('create:Banco:bank:1000'));
    });

    testWidgets('en dólares sin tasa ofrece definirla, y la guarda antes', (tester) async {
      final backend = FakeBackend();
      await openForm(tester, backend);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.enterText(field(0), 'Dólares');
      await tester.enterText(field(1), '50');
      expect(find.text('1 USD vale (opcional)'), findsOneWidget);
      await tester.enterText(field(2), '4.000');
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('setRate:USD:4000'));
      expect(backend.accounts.calls, contains('create:Dólares:bank:50:USD'));
      expect(backend.accounts.accounts.single.currency, 'USD');
      // La tasa se definió antes de crear la cuenta.
      expect(backend.currency.rates['USD']!.rate, 4000);
    });

    testWidgets('la tasa es opcional', (tester) async {
      final backend = FakeBackend();
      await openForm(tester, backend);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'EUR · Euro');
      await tester.enterText(field(0), 'Euros');
      await tester.enterText(field(1), '10');
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(backend.accounts.calls, contains('create:Euros:bank:10:EUR'));
      expect(backend.currency.rates, isEmpty);
    });

    testWidgets('una tasa mal escrita lo impide', (tester) async {
      final backend = FakeBackend();
      await openForm(tester, backend);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');
      await tester.enterText(field(0), 'Dólares');
      await tester.enterText(field(1), '50');
      await tester.enterText(field(2), 'cuatro mil');
      await tester.tap(button('Crear cuenta'));
      await tester.pump();

      expect(find.text('Escribe una tasa mayor que cero. Ejemplo: 4.012,5'), findsOneWidget);
      expect(backend.accounts.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('si la moneda ya tiene tasa, no la vuelve a pedir', (tester) async {
      final backend = FakeBackend(rates: [rate('USD', 4000)]);
      await openForm(tester, backend);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'USD · Dólar estadounidense');

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('vale (opcional)'), findsNothing);
    });

    testWidgets('al editar, la moneda se ve pero no se cambia', (tester) async {
      final backend = FakeBackend(
        accounts: [testAccount('Dólares', balance: 50, currency: 'USD')],
        rates: [rate('USD', 4000)],
      );
      await open(tester, backend, route: AppRoutes.accounts);

      await openAccountForEdit(tester, find.text('Dólares'));

      expect(find.text('USD · Dólar estadounidense'), findsOneWidget);
      expect(find.text('La moneda de una cuenta no se puede cambiar.'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      await tester.tap(button('Guardar'));
      await tester.pumpAndSettle();
      expect(backend.accounts.accounts.single.currency, 'USD');
    });

    testWidgets('la lista dice la moneda de las cuentas que no son de la base', (tester) async {
      await open(
        tester,
        FakeBackend(accounts: [
          testAccount('Ahorros', balance: 1000),
          testAccount('Dólares', balance: 50, currency: 'USD'),
        ]),
        route: AppRoutes.accounts,
      );

      // Las dos son bancos: la de pesos dice solo "Banco"; la otra, también su
      // moneda.
      expect(find.text('Banco'), findsOneWidget);
      expect(find.text('Banco · USD'), findsOneWidget);
      expect(find.text(r'US$50'), findsOneWidget);
    });
  });
}
