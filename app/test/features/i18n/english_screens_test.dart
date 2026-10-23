import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
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
