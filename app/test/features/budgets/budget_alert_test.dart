import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);

BudgetRule _rule(String category, int pesos) => BudgetRule(
  id: 'rule-$category',
  categoryId: 'cat-$category',
  month: _thisMonth,
  cents: pesos * 100,
);

Transaction _spent(String id, String category, double amount) =>
    testTransaction(
      id,
      type: TransactionType.expense,
      accountId: 'id-Bancolombia',
      categoryId: 'cat-$category',
      amount: amount,
      date: DateTime(_now.year, _now.month, 5),
    );

/// Un presupuesto de Mercado de $100.000 con lo ya gastado en el mes.
FakeBackend _backend({double spent = 70000, bool withBudget = true}) =>
    FakeBackend(
      accounts: [testAccount('Bancolombia', balance: 1000000)],
      categories: [
        testCategory('Mercado', CategoryType.expense),
        testCategory('Transporte', CategoryType.expense),
        testCategory('Salario', CategoryType.income),
      ],
      transactions: [if (spent > 0) _spent('antes', 'Mercado', spent)],
      budgets: [if (withBudget) _rule('Mercado', 100000)],
    );

Finder _amountField() => find.byType(TextFormField).at(0);
Finder _submit(String label) => find.widgetWithText(FilledButton, label);

Future<void> _pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Registra un gasto desde el panel.
Future<void> _register(
  WidgetTester tester,
  String amount, {
  String category = 'Mercado',
}) async {
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Nuevo movimiento'),
  );
  await tester.pumpAndSettle();
  await tester.enterText(_amountField(), amount);
  await _pick(
    tester,
    find.byType(DropdownButtonFormField<String>).at(0),
    'Bancolombia',
  );
  await _pick(tester, find.byType(DropdownButtonFormField<String?>), category);
  await tester.tap(_submit('Registrar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initDates);

  group('al registrar un gasto', () {
    testWidgets('avisa al llegar al 80 % del presupuesto', (tester) async {
      final backend = _backend(); // 70 % gastado
      await pumpMiPlata(tester, backend: backend);

      await _register(tester, '15.000'); // queda en 85 %

      expect(backend.transactions.created, hasLength(1));
      expect(
        find.text(
          'Vas en 85 % del presupuesto de Mercado (\$85.000 de \$100.000).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('avisa al pasarse del presupuesto', (tester) async {
      await pumpMiPlata(tester, backend: _backend());

      await _register(tester, '40.000'); // queda en 110 %

      expect(
        find.text(
          'Superaste el presupuesto de Mercado: \$110.000 de \$100.000.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no avisa si todavía va holgado', (tester) async {
      final backend = _backend();
      await pumpMiPlata(tester, backend: backend);

      await _register(tester, '5.000'); // queda en 75 %

      expect(backend.transactions.created, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no repite el aviso de "cerca" si ya estaba cerca', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: _backend(spent: 85000));

      await _register(tester, '5.000'); // de 85 % a 90 %

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sigue avisando cada vez que ya está pasado', (tester) async {
      await pumpMiPlata(tester, backend: _backend(spent: 120000));

      await _register(tester, '1.000');

      expect(
        find.textContaining('Superaste el presupuesto de Mercado'),
        findsOneWidget,
      );
    });

    testWidgets('no avisa de categorías sin presupuesto', (tester) async {
      final backend = _backend();
      await pumpMiPlata(tester, backend: backend);

      await _register(tester, '900.000', category: 'Transporte');

      expect(backend.transactions.created, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no avisa si no hay ningún presupuesto', (tester) async {
      await pumpMiPlata(tester, backend: _backend(withBudget: false));

      await _register(tester, '500.000');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('un aviso no impide guardar: el movimiento se registra igual', (
      tester,
    ) async {
      final backend = _backend();
      await pumpMiPlata(tester, backend: backend);

      await _register(tester, '40.000');

      expect(backend.transactions.created.single.amount, '40000');
      expect(find.text('Nuevo movimiento'), findsOneWidget); // volvió al panel
    });

    testWidgets('si los presupuestos no cargan, el gasto se guarda sin aviso', (
      tester,
    ) async {
      final backend = _backend();
      backend.budgets.error = Exception('sin red');
      await pumpMiPlata(tester, backend: backend);

      await _register(tester, '40.000');

      expect(backend.transactions.created, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('al editar un gasto', () {
    Future<void> edit(WidgetTester tester, String amount) async {
      // Una pantalla alta: la lista del panel se construye bajo demanda.
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mercado').last);
      await tester.pumpAndSettle();
      await tester.enterText(_amountField(), amount);
      await tester.tap(_submit('Guardar cambios'));
      await tester.pumpAndSettle();
    }

    testWidgets('solo cuenta lo que se agrega a lo que ya estaba', (
      tester,
    ) async {
      final backend = _backend(); // 70.000 de 100.000
      await pumpMiPlata(tester, backend: backend);

      await edit(tester, '75.000'); // pasa de 70 % a 75 %: sigue holgado

      expect(backend.transactions.updated, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('avisa si el aumento lo acerca al límite', (tester) async {
      await pumpMiPlata(tester, backend: _backend());

      await edit(tester, '90.000'); // de 70 % a 90 %

      expect(
        find.text(
          'Vas en 90 % del presupuesto de Mercado (\$90.000 de \$100.000).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('bajar el monto de un gasto pasado no avisa', (tester) async {
      await pumpMiPlata(tester, backend: _backend(spent: 120000));

      await edit(tester, '110.000'); // sigue pasado, pero gastó menos

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
