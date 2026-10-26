import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);

DateTime _monthsAgo(int months) => DateTime(_now.year, _now.month - months);

/// Una regla de presupuesto, en pesos (no en centavos), vigente desde [from].
BudgetRule rule(String category, int pesos, {DateTime? from}) => BudgetRule(
  id: 'rule-$category-${(from ?? _thisMonth).month}',
  categoryId: 'cat-$category',
  month: from ?? _thisMonth,
  cents: pesos * 100,
);

int _next = 0;

/// Un gasto de la categoría, por defecto en el mes actual.
Transaction expense(String? category, double amount, {DateTime? month}) {
  final base = month ?? _thisMonth;
  return testTransaction(
    'tx-${_next++}',
    type: TransactionType.expense,
    accountId: 'id-Bancolombia',
    categoryId: category == null ? null : 'cat-$category',
    amount: amount,
    date: DateTime(base.year, base.month, 5),
  );
}

final _categories = <Category>[
  testCategory('Mercado', CategoryType.expense),
  testCategory('Transporte', CategoryType.expense),
  testCategory('Ocio', CategoryType.expense),
  testCategory('Salario', CategoryType.income),
  testCategory('Vieja', CategoryType.expense, archived: true),
];

FakeBackend backendWith({
  List<BudgetRule> rules = const [],
  List<Transaction> transactions = const [],
  List<Account>? accounts,
}) => FakeBackend(
  accounts: accounts ?? [testAccount('Bancolombia', balance: 1000000)],
  categories: _categories,
  transactions: transactions,
  budgets: rules,
);

/// Abre la app y entra a los presupuestos desde el panel.
Future<FakeBackend> openBudgets(
  WidgetTester tester, {
  List<BudgetRule> rules = const [],
  List<Transaction> transactions = const [],
  FakeBackend? backend,
}) async {
  // Una pantalla alta: la lista se construye bajo demanda y así todo cabe.
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fakes =
      backend ?? backendWith(rules: rules, transactions: transactions);
  await pumpMiPlata(tester, backend: fakes);
  await openFromMore(tester, 'Presupuestos');
  return fakes;
}

Finder newBudgetButton() =>
    find.widgetWithText(FloatingActionButton, 'Nuevo presupuesto');
Finder amountField() => find.byType(TextFormField);
Finder save() => find.widgetWithText(FilledButton, 'Guardar');

/// La última escritura que recibió el repositorio de presupuestos.
String lastSet(FakeBackend backend) =>
    backend.budgets.calls.where((call) => call.startsWith('set')).last;

/// El texto de un `Text.rich` completo, con los espacios normalizados.
Finder richTextLike(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.textSpan?.toPlainText() ?? widget.data)
              ?.replaceAll(' ', ' ')
              .replaceAll(RegExp(r'\s+'), ' ') ==
          text,
);

/// La ficha de una categoría con presupuesto (la fila que se toca).
Finder tileOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

void main() {
  setUpAll(initDates);

  group('pantalla', () {
    testWidgets('sin presupuestos ni gastos invita a definir uno', (
      tester,
    ) async {
      await openBudgets(tester);

      expect(
        find.textContaining('Define cuánto quieres gastar'),
        findsOneWidget,
      );
      expect(find.text('Definir un presupuesto'), findsOneWidget);
      expect(find.text('Presupuesto total'), findsNothing);
    });

    testWidgets('muestra lo gastado frente al límite, lo más urgente primero', (
      tester,
    ) async {
      await openBudgets(
        tester,
        rules: [
          rule('Ocio', 300000),
          rule('Mercado', 500000),
          rule('Transporte', 100000),
        ],
        transactions: [
          expense('Ocio', 30000),
          expense('Mercado', 400000),
          expense('Transporte', 150000),
        ],
      );

      // Pasado (150 %), cerca (80 %) y bien (10 %), cada uno con su frase.
      expect(textLike(r'Te pasaste por $50.000'), findsOneWidget);
      expect(textLike(r'Cerca del límite: quedan $100.000'), findsOneWidget);
      expect(textLike(r'Quedan $270.000'), findsOneWidget);
      expect(find.text('150 %'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(find.text('10 %'), findsOneWidget);

      // Lo que más urge va arriba.
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Transporte'), lessThan(top('Mercado')));
      expect(top('Mercado'), lessThan(top('Ocio')));

      // El total junta todo lo presupuestado.
      expect(find.text('Presupuesto total'), findsOneWidget);
      expect(textLike(r'$580.000'), findsOneWidget);
      expect(textLike(r'de $900.000 presupuestados'), findsOneWidget);
      expect(textLike(r'Quedan $320.000'), findsOneWidget);
      expect(find.text('64 %'), findsOneWidget);
      expect(
        find.text('1 categoría superada · 1 cerca del límite'),
        findsOneWidget,
      );
    });

    testWidgets('el gasto de una categoría sin presupuesto aparece aparte', (
      tester,
    ) async {
      await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
        transactions: [
          expense('Mercado', 100000),
          expense('Ocio', 25000),
          expense(null, 10000),
        ],
      );

      expect(find.text('Gastos sin presupuesto'), findsOneWidget);
      expect(find.text('Ocio'), findsOneWidget);
      expect(find.text('Sin categoría'), findsOneWidget);
      // Lo que no tiene presupuesto no entra en el total presupuestado.
      expect(textLike(r'de $500.000 presupuestados'), findsOneWidget);
    });

    testWidgets('tocar un gasto sin presupuesto lo deja definir ahí mismo', (
      tester,
    ) async {
      final backend = await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
        transactions: [expense('Ocio', 25000)],
      );

      await tester.tap(find.text('Ocio'));
      await tester.pumpAndSettle();
      expect(find.text('Presupuesto de Ocio'), findsOneWidget);

      await tester.enterText(amountField(), '80.000');
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(lastSet(backend), 'set cat-Ocio ${_now.year}-${_now.month} 80000');
      // Ya no está en "sin presupuesto": ahora tiene su propia ficha.
      expect(find.text('Gastos sin presupuesto'), findsNothing);
      expect(textLike(r'Quedan $55.000'), findsOneWidget);
    });

    testWidgets('"Sin categoría" no se puede presupuestar', (tester) async {
      await openBudgets(tester, transactions: [expense(null, 10000)]);

      await tester.tap(find.text('Sin categoría'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('si no se pudo cargar, avisa y deja reintentar', (
      tester,
    ) async {
      final backend = backendWith(rules: [rule('Mercado', 500000)]);
      backend.budgets.error = Exception('sin red');
      await openBudgets(tester, backend: backend);

      expect(find.textContaining('No se pudo completar'), findsOneWidget);

      backend.budgets.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsOneWidget);
    });
  });

  group('definir', () {
    testWidgets('un presupuesto nuevo: categoría y monto, desde este mes', (
      tester,
    ) async {
      final backend = await openBudgets(tester);

      await tester.tap(newBudgetButton());
      await tester.pumpAndSettle();
      expect(find.text('Nuevo presupuesto'), findsWidgets);
      expect(find.textContaining('Rige desde'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mercado').last);
      await tester.pumpAndSettle();
      await tester.enterText(amountField(), '800.000');
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        lastSet(backend),
        'set cat-Mercado ${_now.year}-${_now.month} 800000',
      );
      expect(find.text('Presupuesto total'), findsOneWidget);
      expect(textLike(r'Quedan $800.000'), findsWidgets);
    });

    testWidgets('solo ofrece categorías de gasto activas y sin presupuesto', (
      tester,
    ) async {
      await openBudgets(tester, rules: [rule('Mercado', 500000)]);

      await tester.tap(newBudgetButton());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      Finder option(String name) =>
          find.widgetWithText(DropdownMenuItem<String>, name);
      expect(option('Transporte'), findsOneWidget);
      expect(option('Ocio'), findsOneWidget);
      expect(option('Mercado'), findsNothing); // ya tiene
      expect(option('Salario'), findsNothing); // es de ingreso
      expect(option('Vieja'), findsNothing); // archivada
    });

    testWidgets('pide elegir categoría y un monto mayor que cero', (
      tester,
    ) async {
      final backend = await openBudgets(tester);

      await tester.tap(newBudgetButton());
      await tester.pumpAndSettle();
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(find.text('Elige una categoría'), findsOneWidget);
      expect(find.text('Ingresa el monto'), findsOneWidget);

      await tester.enterText(amountField(), '0');
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(find.text('El monto debe ser mayor que cero'), findsOneWidget);
      expect(backend.budgets.calls.where((c) => c.startsWith('set')), isEmpty);
    });

    testWidgets(
      'si todas las categorías ya tienen, lo dice y no deja guardar',
      (tester) async {
        await openBudgets(
          tester,
          rules: [
            rule('Mercado', 500000),
            rule('Transporte', 100000),
            rule('Ocio', 100000),
          ],
        );

        await tester.tap(newBudgetButton());
        await tester.pumpAndSettle();

        expect(
          find.text('Todas tus categorías de gasto ya tienen presupuesto.'),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(save()).onPressed, isNull);
      },
    );

    testWidgets('editar trae el monto actual y guarda el nuevo', (
      tester,
    ) async {
      final backend = await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
        transactions: [expense('Mercado', 100000)],
      );

      await tester.tap(tileOf('Mercado'));
      await tester.pumpAndSettle();
      expect(find.text('Presupuesto de Mercado'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(amountField()).controller!.text,
        '500000',
      );

      await tester.enterText(amountField(), '600.000');
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        lastSet(backend),
        'set cat-Mercado ${_now.year}-${_now.month} 600000',
      );
      expect(textLike(r'Quedan $500.000'), findsWidgets); // ficha y total
      // Reemplaza la regla de este mes: no se acumulan filas.
      expect(backend.budgets.rules, hasLength(1));
    });

    testWidgets('quitar el presupuesto deja la categoría sin límite', (
      tester,
    ) async {
      final backend = await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
        transactions: [expense('Mercado', 100000)],
      );

      await tester.tap(tileOf('Mercado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar el presupuesto'));
      await tester.pumpAndSettle();

      expect(lastSet(backend), 'set cat-Mercado ${_now.year}-${_now.month} 0');
      expect(find.text('Presupuesto total'), findsNothing);
      // El gasto sigue ahí, ahora sin presupuesto.
      expect(find.text('Gastos sin presupuesto'), findsOneWidget);
    });

    testWidgets('crear uno no muestra "quitar"', (tester) async {
      await openBudgets(tester);

      await tester.tap(newBudgetButton());
      await tester.pumpAndSettle();

      expect(find.text('Quitar el presupuesto'), findsNothing);
    });

    testWidgets('si falla al guardar, avisa y la hoja sigue abierta', (
      tester,
    ) async {
      final backend = await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
      );

      await tester.tap(tileOf('Mercado'));
      await tester.pumpAndSettle();
      backend.budgets.error = Exception('sin red');
      await tester.enterText(amountField(), '600.000');
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo completar'), findsOneWidget);
      expect(find.text('Presupuesto de Mercado'), findsOneWidget);
    });
  });

  group('meses', () {
    testWidgets('un mes pasado se consulta, pero no se edita', (tester) async {
      final backend = await openBudgets(
        tester,
        rules: [rule('Mercado', 500000, from: _monthsAgo(3))],
        transactions: [expense('Mercado', 100000, month: _monthsAgo(1))],
      );

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(textLike(r'Quedan $400.000'), findsWidgets);
      expect(newBudgetButton(), findsNothing);

      await tester.tap(tileOf('Mercado'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(backend.budgets.calls.where((c) => c.startsWith('set')), isEmpty);
    });

    testWidgets('un cambio de presupuesto no reescribe los meses anteriores', (
      tester,
    ) async {
      await openBudgets(
        tester,
        rules: [
          rule('Mercado', 500000, from: _monthsAgo(3)),
          rule('Mercado', 700000),
        ],
        transactions: [
          expense('Mercado', 100000, month: _monthsAgo(1)),
          expense('Mercado', 100000),
        ],
      );

      // Este mes rige el monto nuevo...
      expect(textLike(r'Quedan $600.000'), findsWidgets);

      // ...y el mes pasado sigue con el que tenía.
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(textLike(r'Quedan $400.000'), findsWidgets);
      expect(textLike(r'Quedan $600.000'), findsNothing);
    });

    testWidgets('antes del primer presupuesto el mes no tiene ninguno', (
      tester,
    ) async {
      await openBudgets(
        tester,
        rules: [rule('Mercado', 500000)],
        transactions: [expense('Mercado', 100000, month: _monthsAgo(1))],
      );

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Presupuesto total'), findsNothing);
      // El gasto de ese mes no tenía presupuesto.
      expect(find.text('Gastos sin presupuesto'), findsOneWidget);
    });

    testWidgets('un mes pasado vacío ofrece volver al mes actual', (
      tester,
    ) async {
      await openBudgets(tester, rules: [rule('Mercado', 500000)]);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(
        find.text('No había presupuestos ni gastos en este mes.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Ir al mes actual'));
      await tester.pumpAndSettle();
      expect(find.text('Presupuesto total'), findsOneWidget);
    });
  });

  group('panel principal', () {
    testWidgets('sin presupuestos no hay tarjeta', (tester) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backendWith());

      expect(find.text('Presupuestos'), findsNothing);
    });

    testWidgets('con presupuestos resume el mes y lo que pide atención', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: backendWith(
          rules: [
            rule('Mercado', 100000),
            rule('Transporte', 100000),
            rule('Ocio', 100000),
          ],
          transactions: [
            expense('Mercado', 120000),
            expense('Transporte', 85000),
            expense('Ocio', 10000),
          ],
        ),
      );

      expect(find.text('Presupuestos'), findsOneWidget);
      expect(richTextLike(r'$215.000 de $300.000'), findsOneWidget);
      expect(textLike(r'Quedan $85.000'), findsOneWidget);
      expect(
        find.text('1 categoría superada · 1 cerca del límite'),
        findsOneWidget,
      );
    });

    testWidgets('si todo va bien no marca nada de más', (tester) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: backendWith(
          rules: [rule('Mercado', 100000)],
          transactions: [expense('Mercado', 10000)],
        ),
      );

      expect(textLike(r'Quedan $90.000'), findsOneWidget);
      expect(find.textContaining('superada'), findsNothing);
      expect(find.textContaining('cerca del límite'), findsNothing);
    });

    testWidgets('al tocarla abre los presupuestos', (tester) async {
      tallView(tester);
      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: backendWith(rules: [rule('Mercado', 100000)]),
      );

      await tester.tap(textLike(r'Quedan $100.000'));
      await tester.pumpAndSettle();

      expect(find.text('Presupuesto total'), findsOneWidget);
    });

    testWidgets('si falla la carga, el panel sigue igual', (tester) async {
      final backend = backendWith(rules: [rule('Mercado', 100000)]);
      backend.budgets.error = Exception('sin red');
      tallView(tester);
      await pumpMiPlata(tester, backend: backend);

      expect(find.text('Presupuestos'), findsNothing);
      // El encabezado de la sección (la barra de abajo también dice Cuentas).
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('Cuentas')),
        findsOneWidget,
      );
    });
  });

  group('desde el resumen mensual', () {
    testWidgets('hay un enlace a los presupuestos', (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: backendWith(
          rules: [rule('Mercado', 500000)],
          transactions: [expense('Mercado', 100000)],
        ),
      );
      await openFromMore(tester, 'Resumen mensual');

      await tester.tap(find.text('Cuánto llevas gastado de lo que planeaste'));
      await tester.pumpAndSettle();

      expect(find.text('Presupuesto total'), findsOneWidget);
    });
  });
}
