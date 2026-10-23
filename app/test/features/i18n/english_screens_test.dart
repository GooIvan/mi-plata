import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime _day(int daysAgo) => DateTime(_now.year, _now.month, _now.day - daysAgo);

/// Los textos en español que no son iguales en inglés. Si alguno aparece en una
/// pantalla en inglés, es que ese texto quedó escrito a mano.
Set<String> _spanishOnly() {
  Map<String, dynamic> load(String language) =>
      jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;
  final es = load('es');
  final en = load('en');
  return {
    for (final entry in es.entries)
      if (!entry.key.startsWith('@') &&
          !(entry.value as String).contains('{') &&
          entry.value != en[entry.key])
        entry.value as String,
  };
}

/// Todos los textos que hay en pantalla ahora.
Iterable<String> _visibleTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data != null) text.data!,
];

void _expectNoSpanish(WidgetTester tester, Set<String> spanish) {
  final leaks = _visibleTexts(tester).where(spanish.contains).toSet();
  expect(leaks, isEmpty, reason: 'texto en español en una pantalla en inglés');
}

FakeBackend _backend() {
  final backend = FakeBackend(
    accounts: [
      testAccount('Bancolombia', balance: 1000000),
      testAccount('Nequi', type: AccountType.wallet, balance: 50000),
      testAccount('Visa', type: AccountType.card, balance: -200000),
    ],
    categories: [
      testCategory('Mercado', CategoryType.expense),
      testCategory('Transporte', CategoryType.expense),
      testCategory('Salario', CategoryType.income),
    ],
    transactions: [
      testTransaction(
        't1',
        type: TransactionType.expense,
        accountId: 'id-Bancolombia',
        categoryId: 'cat-Mercado',
        amount: 120000,
        date: _day(0),
      ),
      testTransaction(
        't2',
        type: TransactionType.income,
        accountId: 'id-Bancolombia',
        categoryId: 'cat-Salario',
        amount: 3000000,
        date: _day(1),
      ),
      testTransaction(
        't3',
        type: TransactionType.transfer,
        accountId: 'id-Bancolombia',
        destinationAccountId: 'id-Nequi',
        amount: 50000,
        date: _day(2),
      ),
    ],
    budgets: [
      BudgetRule(
        id: 'r1',
        categoryId: 'cat-Mercado',
        month: DateTime(_now.year, _now.month),
        cents: 15000000,
      ),
    ],
  );
  backend.debts
    ..seedDebt(
      counterparty: 'Juan',
      amount: 500000,
      payments: [200000],
      dueDate: DateTime(_now.year, _now.month, _now.day + 3),
    )
    ..seedDebt(
      counterparty: 'Pedro',
      amount: 80000,
      dueDate: DateTime(_now.year, _now.month, _now.day - 5),
    )
    ..seedDebt(
      direction: DebtDirection.receivable,
      counterparty: 'María',
      amount: 300000,
    );
  return backend;
}

/// Pesos, dólares (con tasa) y euros (sin tasa), para ver todo lo de monedas.
FakeBackend _multiCurrencyBackend() => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Dólares', balance: 100, currency: 'USD'),
    testAccount('Euros', balance: 50, currency: 'EUR'),
  ],
  categories: [testCategory('Mercado', CategoryType.expense)],
  rates: [
    ExchangeRate(currency: 'USD', rate: 4000, updatedAt: DateTime.now()),
  ],
);

/// Un arriendo vencido, una suscripción próxima y un seguro lejano.
FakeBackend _recurringBackend() {
  final backend = FakeBackend(
    accounts: [testAccount('Bancolombia', balance: 1000000)],
    categories: [testCategory('Vivienda', CategoryType.expense)],
  );
  backend.recurring
    ..seed(
      name: 'Arriendo',
      amount: 1500000,
      categoryId: 'cat-Vivienda',
      nextDueDate: DateTime(_now.year, _now.month, _now.day - 2),
    )
    ..seed(
      name: 'Netflix',
      amount: 30000,
      nextDueDate: DateTime(_now.year, _now.month, _now.day + 3),
    )
    ..seed(
      name: 'Seguro',
      amount: 90000,
      nextDueDate: DateTime(_now.year, _now.month, _now.day + 30),
    );
  return backend;
}

Future<void> _open(WidgetTester tester, [String? route]) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpMiPlata(tester, backend: _backend(), language: 'en');
  if (route != null) await goTo(tester, route);
}

void main() {
  late Set<String> spanish;
  var realFonts = false;

  setUpAll(() async {
    await initDates();
    realFonts = await loadRealFonts();
    spanish = _spanishOnly();
    expect(spanish, isNotEmpty);
  });

  testWidgets('el detector sí encuentra español (la prueba no es vacía)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMiPlata(tester, backend: _backend(), language: 'es');

    expect(_visibleTexts(tester).where(spanish.contains), isNotEmpty);
  });

  group('panel', () {
    testWidgets('todo en inglés, con montos a la inglesa', (tester) async {
      await _open(tester);

      expect(find.text('Total money'), findsOneWidget);
      // 3.630.000 + 100.000 - 200.000, con el movimiento, la transferencia y el abono.
      expect(textLike(r'$3,530,000'), findsOneWidget);
      expect(find.text('In 3 accounts'), findsOneWidget);
      expect(find.text('Recent transactions'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('Today'), findsNothing); // el panel no agrupa por día
      for (final tooltip in ['Monthly summary', 'Budgets', 'Categories', 'Settings']) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      }
      expect(find.text('Expense'), findsNothing);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el botón de nuevo movimiento', (tester) async {
      await _open(tester);

      expect(find.widgetWithText(FloatingActionButton, 'New transaction'), findsOneWidget);
    });
  });

  group('cuentas', () {
    testWidgets('la lista y su formulario', (tester) async {
      await _open(tester, AppRoutes.accounts);

      expect(find.widgetWithText(AppBar, 'Accounts'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Digital wallet'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text('New account'));
      await tester.pumpAndSettle();
      expect(find.text('Initial balance'), findsOneWidget);
      expect(find.text('Leave it empty if it starts at zero'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      // Un saldo mal escrito (en formato colombiano) se explica en inglés.
      await tester.enterText(find.byType(TextFormField).at(0), 'Cash box');
      await tester.enterText(find.byType(TextFormField).at(1), '1.500,50');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();
      expect(find.text('Invalid amount. Example: 1,500,000 or 1500.50'), findsOneWidget);
    });
  });

  group('categorías', () {
    testWidgets('pestañas, estados vacíos y formulario', (tester) async {
      await _open(tester, AppRoutes.categories);

      expect(find.widgetWithText(Tab, 'Expenses'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Income'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      expect(find.text('New expense category'), findsOneWidget);
      expect(find.text('e.g. Pets'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });
  });

  group('movimientos', () {
    testWidgets('la lista agrupa por día en inglés', (tester) async {
      await _open(tester, AppRoutes.transactions);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(textLike(r'-$120,000'), findsOneWidget);
      expect(textLike(r'+$3,000,000'), findsOneWidget);
      expect(find.text('Bancolombia → Nequi'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el filtro y la búsqueda', (tester) async {
      await _open(tester, AppRoutes.transactions);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Filter transactions'), findsOneWidget);
      expect(find.text('All accounts'), findsOneWidget);
      expect(find.text('Any date'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el formulario acepta montos con coma de miles y punto decimal', (
      tester,
    ) async {
      final backend = _backend();
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpMiPlata(tester, backend: backend, language: 'en');

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.widgetWithText(FilledButton, 'Record'));
      await tester.pump();
      expect(find.text('Enter the amount'), findsOneWidget);
      expect(find.text('Choose an account'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '1,500.50');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bancolombia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record'));
      await tester.pumpAndSettle();

      expect(backend.transactions.created.single.amount, '1500.50');
    });

    testWidgets('el aviso de saldo negativo está en inglés', (tester) async {
      await _open(tester);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'New transaction'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '140,000');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nequi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record'));
      await tester.pumpAndSettle();

      expect(find.text('Record it anyway?'), findsOneWidget);
      expect(find.textContaining('Nequi will be left at -\$40,000.'), findsOneWidget);
      expect(find.text('Fix it'), findsOneWidget);
      expect(find.text('Record anyway'), findsOneWidget);
    });
  });

  group('deudas', () {
    testWidgets('lista, estados y totales', (tester) async {
      await _open(tester, AppRoutes.debts);

      expect(find.widgetWithText(Tab, 'I owe'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Owed to me'), findsOneWidget);
      expect(find.text('You owe in total'), findsOneWidget);
      expect(textLike(r'$380,000'), findsWidgets);
      expect(find.textContaining('Due in 3 days'), findsOneWidget);
      expect(find.textContaining('Overdue by 5 days'), findsOneWidget);
      expect(find.textContaining('of \$500,000'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('detalle, abono y formulario', (tester) async {
      await _open(tester, AppRoutes.debts);

      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();
      expect(find.text('You owe Juan'), findsOneWidget);
      expect(find.text('remaining'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.textContaining('Paid \$200,000'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(find.text('Pay Juan'), findsOneWidget);
      expect(find.text('Pay all'), findsOneWidget);
      expect(find.text('Payment amount'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el formulario de deuda', (tester) async {
      await _open(tester, AppRoutes.debts);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New debt'));
      await tester.pumpAndSettle();
      expect(find.text('Who you owe'), findsOneWidget);
      expect(find.text('Total amount'), findsOneWidget);
      expect(find.text('Record the money in an account'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });
  });

  group('resumen', () {
    testWidgets('gráficos, comparaciones y ritmo de gasto', (tester) async {
      await _open(tester, AppRoutes.summary);

      expect(find.widgetWithText(AppBar, 'Monthly summary'), findsOneWidget);
      expect(find.text('Balance for the month'), findsOneWidget);
      expect(find.text('Spending pace'), findsOneWidget);
      expect(find.text('Daily average'), findsOneWidget);
      expect(find.text('Income vs. expenses'), findsOneWidget);
      expect(find.text('Where does the money go?'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next month'), findsOneWidget);
    });
  });

  group('presupuestos', () {
    testWidgets('pantalla, estado y formulario', (tester) async {
      await _open(tester, AppRoutes.budgets);

      expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);
      expect(find.text('Total budget'), findsOneWidget);
      expect(find.text('With a budget'), findsOneWidget);
      expect(find.textContaining('\$30,000 left'), findsWidgets);
      expect(find.text('80%'), findsWidgets);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New budget'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly amount'), findsOneWidget);
      expect(find.text('Expense category'), findsOneWidget);
      expect(find.textContaining('Applies from'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });
  });

  group('monedas', () {
    Future<void> openMulti(WidgetTester tester, [String? route]) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpMiPlata(
        tester,
        backend: _multiCurrencyBackend(),
        language: 'en',
      );
      if (route != null) await goTo(tester, route);
    }

    testWidgets('el panel, con el aviso de una moneda sin tasa', (tester) async {
      await openMulti(tester);

      expect(textLike(r'$1,400,000'), findsOneWidget);
      expect(
        find.text('No exchange rate for EUR: not included in the total. '),
        findsNothing, // el aviso es un texto con enlace, no una sola cadena
      );
      expect(find.textContaining('No exchange rate for EUR'), findsOneWidget);
      expect(find.text('Set rate'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('ajustes de moneda y la hoja de la moneda base', (tester) async {
      await openMulti(tester, AppRoutes.settings);

      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('Base currency'), findsOneWidget);
      expect(find.text('COP · Colombian peso'), findsOneWidget);
      expect(find.text('What each currency is worth in your base currency'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text('Base currency'));
      await tester.pumpAndSettle();
      expect(find.text('All your money, summaries and budgets are shown in this currency.'), findsOneWidget);
      expect(find.text('Change base currency'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('las tasas y su hoja', (tester) async {
      await openMulti(tester, AppRoutes.rates);

      expect(find.widgetWithText(AppBar, 'Exchange rates'), findsOneWidget);
      expect(find.text('EUR · Euro'), findsOneWidget);
      expect(find.text('USD · US dollar'), findsOneWidget);
      expect(find.text('No rate'), findsOneWidget);
      expect(find.textContaining(r'1 USD = $4,000'), findsOneWidget);
      expect(find.textContaining('Updated today'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text('USD · US dollar'));
      await tester.pumpAndSettle();
      expect(find.text('USD rate'), findsOneWidget);
      expect(find.text('1 USD is worth'), findsOneWidget);
      expect(find.text('Remove the rate'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el formulario de cuenta con moneda y tasa', (tester) async {
      await openMulti(tester, AppRoutes.accounts);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GBP · Pound sterling').last);
      await tester.pumpAndSettle();

      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('1 GBP is worth (optional)'), findsOneWidget);
      expect(find.text("Without a rate, this account isn't added to your total money."), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('una transferencia entre monedas', (tester) async {
      await openMulti(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<TransactionType>),
        matching: find.text('Transfer'),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '400,000');
      for (final (index, option) in [(0, 'Bancolombia'), (1, 'Dólares · USD')]) {
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextFormField).at(1), '99.5');
      await tester.pump();

      expect(find.text('Amount sent (COP)'), findsOneWidget);
      expect(find.text('Amount received (USD)'), findsOneWidget);
      expect(find.text('1 COP = 0.000249 USD'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el formulario de deuda con moneda', (tester) async {
      await openMulti(tester, AppRoutes.debts);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('COP · Colombian peso'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });
  });

  group('pagos recurrentes', () {
    Future<void> openRecurring(WidgetTester tester, [String? route]) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpMiPlata(tester, backend: _recurringBackend(), language: 'en');
      if (route != null) await goTo(tester, route);
    }

    testWidgets('el panel avisa de lo que vence pronto', (tester) async {
      await openRecurring(tester);

      expect(find.text('Recurring payments'), findsOneWidget);
      expect(find.text('Overdue by 2 days'), findsOneWidget);
      expect(find.text('Upcoming payment: due in 3 days'), findsOneWidget);
      expect(find.text('I paid'), findsNWidgets(2));
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('la lista', (tester) async {
      await openRecurring(tester, AppRoutes.recurring);

      expect(find.widgetWithText(AppBar, 'Recurring payments'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Every month'), findsNWidgets(3));
      expect(find.textContaining('Next payment on'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el detalle', (tester) async {
      await openRecurring(tester, AppRoutes.recurring);

      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      expect(find.text('Recorded payments'), findsOneWidget);
      expect(find.text("You haven't recorded any payments yet."), findsOneWidget);
      expect(find.text('Paid from: Bancolombia'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('la hoja de confirmación', (tester) async {
      await openRecurring(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'I paid').first);
      await tester.pumpAndSettle();

      expect(find.text('Payment for Arriendo'), findsOneWidget);
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.text('Skip this payment'), findsOneWidget);
      expect(find.text('Paid from'), findsOneWidget);
      _expectNoSpanish(tester, spanish);
    });

    testWidgets('el formulario', (tester) async {
      await openRecurring(tester, AppRoutes.recurring);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New recurring payment'), findsOneWidget);
      expect(find.text('Next payment'), findsOneWidget);
      expect(find.text('Ends (optional)'), findsOneWidget);
      expect(find.text('Nothing is deducted until you confirm you paid.'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.widgetWithText(FilledButton, 'Create recurring payment'));
      await tester.pump();
      expect(find.text('Give the payment a name'), findsOneWidget);
      expect(find.text('Enter the amount'), findsOneWidget);
    });
  });

  group('acceso', () {
    testWidgets('inicio de sesión y registro', (tester) async {
      await pumpMiPlata(tester, auth: FakeAuthRepository(), language: 'en');

      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();
      expect(find.text('Create your account to get started'), findsOneWidget);
      _expectNoSpanish(tester, spanish);

      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Create a password'), findsOneWidget);
    });
  });

  // Los textos en inglés tienen otro largo: en un teléfono angosto no deben
  // desbordar (un desborde hace fallar la prueba).
  group('sin desbordes en un teléfono angosto', () {
    // Sin las fuentes reales el texto sale demasiado ancho y desborda siempre.
    setUp(() => expect(realFonts, isTrue, reason: 'faltan las fuentes del SDK'));

    for (final language in ['en', 'es']) {
      Future<void> phone(WidgetTester tester, [String? route]) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpMiPlata(tester, backend: _backend(), language: language);
        if (route != null) await goTo(tester, route);
      }

      for (final route in [
        AppRoutes.recurring,
        AppRoutes.rates,
        AppRoutes.dashboard,
        AppRoutes.accounts,
        AppRoutes.categories,
        AppRoutes.transactions,
        AppRoutes.summary,
        AppRoutes.debts,
        AppRoutes.budgets,
        AppRoutes.settings,
      ]) {
        testWidgets('$language: $route', (tester) async {
          await phone(tester, route);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('$language: formularios y hojas', (tester) async {
        await phone(tester, AppRoutes.accounts);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10)); // cierra la hoja
        await tester.pumpAndSettle();

        await goTo(tester, AppRoutes.transactions);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump(); // con los errores de validación a la vista
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: monedas, hojas y formularios', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpMiPlata(
          tester,
          backend: _multiCurrencyBackend(),
          language: language,
        );

        // La hoja de la moneda base, con la tasa a la vista.
        await goTo(tester, AppRoutes.settings);
        await tester.tap(find.byIcon(Icons.payments_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('EUR ·').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Una tasa, con un error de validación a la vista.
        await goTo(tester, AppRoutes.rates);
        await tester.tap(find.textContaining('USD ·'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '0');
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Una cuenta en otra moneda, con el campo de la tasa.
        await goTo(tester, AppRoutes.accounts);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('GBP ·').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: transferencia entre monedas', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpMiPlata(
          tester,
          backend: _multiCurrencyBackend(),
          language: language,
        );
        await goTo(tester, AppRoutes.transactions);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        // Elige origen y destino de monedas distintas.
        final transferLabel = language == 'en' ? 'Transfer' : 'Transferencia';
        await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<TransactionType>),
          matching: find.text(transferLabel),
        ));
        await tester.pumpAndSettle();
        for (final (index, option) in [(0, 'Bancolombia'), (1, 'Dólares · USD')]) {
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
          await tester.pumpAndSettle();
          await tester.tap(find.text(option).last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextFormField).at(0), '400000');
        await tester.enterText(find.byType(TextFormField).at(1), '99.5');
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: pagos recurrentes, detalle, hoja y formulario', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpMiPlata(
          tester,
          backend: _recurringBackend(),
          language: language,
        );

        // La hoja de confirmar, con su aviso y sus botones.
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // El detalle.
        await goTo(tester, AppRoutes.recurring);
        await tester.tap(find.text('Netflix'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // El formulario, con los errores de validación a la vista.
        await tester.tap(find.byTooltip(language == 'en' ? 'Edit recurring payment' : 'Editar pago recurrente'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '');
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: abono', (tester) async {
        await phone(tester, AppRoutes.debts);
        await tester.tap(find.text('Juan'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump(); // con los errores de validación a la vista

        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: deuda', (tester) async {
        await phone(tester, AppRoutes.debts);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: presupuesto', (tester) async {
        await phone(tester, AppRoutes.budgets);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
