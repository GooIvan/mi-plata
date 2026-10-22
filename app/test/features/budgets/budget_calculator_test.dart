import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/budgets/domain/budget_calculator.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';

int _next = 0;

BudgetRule rule(String category, DateTime month, int pesos) => BudgetRule(
  id: 'r${_next++}',
  categoryId: category,
  month: month,
  cents: pesos * 100,
);

DateTime m(int year, int month) => DateTime(year, month);

void main() {
  group('BudgetRule.fromJson', () {
    test('lee una fila de budgets, con el monto en centavos', () {
      final parsed = BudgetRule.fromJson({
        'id': 'b1',
        'user_id': 'u1',
        'category_id': 'c1',
        'effective_month': '2026-10-01',
        'amount': 1200000.5,
        'created_at': '2026-10-01T10:00:00Z',
      });

      expect(parsed.categoryId, 'c1');
      expect(parsed.month, DateTime(2026, 10));
      expect(parsed.cents, 120000050);
    });
  });

  group('statusOf', () {
    // Límite de 1.000 pesos (100.000 centavos).
    BudgetStatus status(int spent) => BudgetCalculator.statusOf(spent, 100000);

    test('dentro del presupuesto, con margen', () {
      expect(status(0), BudgetStatus.ok);
      expect(status(79999), BudgetStatus.ok);
    });

    test('desde el 80 % exacto está cerca', () {
      expect(status(80000), BudgetStatus.near);
      expect(status(99999), BudgetStatus.near);
    });

    test('gastar justo el presupuesto no es pasarse', () {
      expect(status(100000), BudgetStatus.near);
    });

    test('un centavo de más ya es pasarse', () {
      expect(status(100001), BudgetStatus.over);
      expect(status(250000), BudgetStatus.over);
    });
  });

  group('límite vigente en cada mes', () {
    test('rige la regla más reciente que no sea posterior al mes', () {
      final rules = [
        rule('mercado', m(2026, 1), 500000),
        rule('mercado', m(2026, 4), 700000),
      ];

      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 3))['mercado'],
        50000000,
      );
      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 4))['mercado'],
        70000000,
      );
      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 12))['mercado'],
        70000000,
      );
    });

    test('subir un presupuesto no reescribe los meses anteriores', () {
      final rules = [
        rule('mercado', m(2026, 1), 500000),
        rule('mercado', m(2026, 11), 900000),
      ];

      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 10))['mercado'],
        50000000,
      );
    });

    test('antes de la primera regla no hay presupuesto', () {
      final rules = [rule('mercado', m(2026, 6), 500000)];

      expect(BudgetCalculator.effectiveLimits(rules, m(2026, 5)), isEmpty);
    });

    test('una regla en cero quita el presupuesto desde ese mes', () {
      final rules = [
        rule('mercado', m(2026, 1), 500000),
        rule('mercado', m(2026, 6), 0),
      ];

      expect(
        BudgetCalculator.effectiveLimits(
          rules,
          m(2026, 5),
        ).containsKey('mercado'),
        isTrue,
      );
      expect(BudgetCalculator.effectiveLimits(rules, m(2026, 6)), isEmpty);
      expect(BudgetCalculator.effectiveLimits(rules, m(2026, 9)), isEmpty);
    });

    test('un presupuesto quitado se puede volver a poner', () {
      final rules = [
        rule('mercado', m(2026, 1), 500000),
        rule('mercado', m(2026, 6), 0),
        rule('mercado', m(2026, 9), 600000),
      ];

      expect(BudgetCalculator.effectiveLimits(rules, m(2026, 7)), isEmpty);
      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 9))['mercado'],
        60000000,
      );
    });

    test('cada categoría tiene su propia historia', () {
      final rules = [
        rule('mercado', m(2026, 1), 500000),
        rule('transporte', m(2026, 3), 200000),
      ];

      final limits = BudgetCalculator.effectiveLimits(rules, m(2026, 2));
      expect(limits.keys, ['mercado']);
      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 3)).keys,
        containsAll(['mercado', 'transporte']),
      );
    });

    test('el orden en que llegan las reglas no importa', () {
      final rules = [
        rule('mercado', m(2026, 4), 700000),
        rule('mercado', m(2026, 1), 500000),
      ];

      expect(
        BudgetCalculator.effectiveLimits(rules, m(2026, 5))['mercado'],
        70000000,
      );
      expect(
        BudgetCalculator.effectiveLimits(rules.reversed, m(2026, 5))['mercado'],
        70000000,
      );
    });

    test('acepta cualquier día del mes como referencia', () {
      final rules = [rule('mercado', m(2026, 4), 700000)];

      expect(
        BudgetCalculator.effectiveLimits(
          rules,
          DateTime(2026, 4, 17, 20),
        )['mercado'],
        70000000,
      );
    });
  });

  group('overview', () {
    final rules = [
      rule('mercado', m(2026, 1), 1000000),
      rule('transporte', m(2026, 1), 200000),
      rule('ocio', m(2026, 1), 300000),
    ];

    BudgetOverview overviewFor(Map<String?, int> spent) =>
        BudgetCalculator.overview(
          rules: rules,
          month: m(2026, 10),
          expenseCentsByCategory: spent,
        );

    test('cada categoría con presupuesto lleva lo gastado y lo que queda', () {
      final overview = overviewFor({
        'mercado': 40000000,
        'transporte': 5000000,
      });

      final mercado = overview.budgeted.firstWhere(
        (b) => b.categoryId == 'mercado',
      );
      expect(mercado.limitCents, 100000000);
      expect(mercado.spentCents, 40000000);
      expect(mercado.remainingCents, 60000000);
      expect(mercado.fraction, 0.4);
      expect(mercado.status, BudgetStatus.ok);
    });

    test('una categoría con presupuesto y sin gasto aparece en cero', () {
      final overview = overviewFor({'mercado': 100});

      final ocio = overview.budgeted.firstWhere((b) => b.categoryId == 'ocio');
      expect(ocio.spentCents, 0);
      expect(ocio.status, BudgetStatus.ok);
    });

    test('las más pasadas o cerca del límite van primero', () {
      final overview = overviewFor({
        'mercado': 20000000, // 20 %
        'transporte': 25000000, // 125 %
        'ocio': 27000000, // 90 %
      });

      expect(overview.budgeted.map((b) => b.categoryId), [
        'transporte',
        'ocio',
        'mercado',
      ]);
      expect(overview.budgeted.first.status, BudgetStatus.over);
      expect(overview.budgeted.first.remainingCents, -5000000);
    });

    test(
      'lo gastado fuera de los presupuestos va aparte, de mayor a menor',
      () {
        final overview = overviewFor({
          'mercado': 100,
          'ropa': 5000,
          'salud': 9000,
          null: 7000, // sin categoría
        });

        expect(overview.unbudgeted.map((u) => u.categoryId), [
          'salud',
          null,
          'ropa',
        ]);
        expect(overview.unbudgeted.first.spentCents, 9000);
        // Lo de "mercado" tiene presupuesto: no se repite aquí.
        expect(
          overview.unbudgeted.any((u) => u.categoryId == 'mercado'),
          isFalse,
        );
      },
    );

    test(
      'una categoría con el presupuesto quitado cuenta como sin presupuesto',
      () {
        final cleared = [
          rule('ropa', m(2026, 1), 100000),
          rule('ropa', m(2026, 5), 0),
        ];
        final overview = BudgetCalculator.overview(
          rules: cleared,
          month: m(2026, 10),
          expenseCentsByCategory: {'ropa': 9000},
        );

        expect(overview.hasBudgets, isFalse);
        expect(overview.unbudgeted.single.categoryId, 'ropa');
      },
    );

    test('los totales son solo de las categorías con presupuesto', () {
      final overview = overviewFor({
        'mercado': 40000000,
        'transporte': 5000000,
        'ropa': 99999999, // sin presupuesto: no suma
      });

      expect(
        overview.totalLimitCents,
        150000000,
      ); // 1.000.000 + 200.000 + 300.000
      expect(overview.totalSpentCents, 45000000);
      expect(overview.totalRemainingCents, 105000000);
      expect(overview.fraction, 0.3);
      expect(overview.status, BudgetStatus.ok);
    });

    test('el estado del conjunto sigue las mismas reglas', () {
      expect(
        overviewFor({
          'mercado': 100000000,
          'transporte': 20000000,
          'ocio': 5000000,
        }).status,
        BudgetStatus.near,
      );
      expect(
        overviewFor({
          'mercado': 140000000,
          'transporte': 20000000,
          'ocio': 5000000,
        }).status,
        BudgetStatus.over,
      );
    });

    test('sin presupuestos ni gastos todo queda vacío', () {
      final overview = BudgetCalculator.overview(
        rules: const [],
        month: m(2026, 10),
        expenseCentsByCategory: const {},
      );

      expect(overview.hasBudgets, isFalse);
      expect(overview.budgeted, isEmpty);
      expect(overview.unbudgeted, isEmpty);
      expect(overview.fraction, 0);
    });

    test('un gasto de cero no aparece como "sin presupuesto"', () {
      final overview = overviewFor({'ropa': 0});

      expect(overview.unbudgeted, isEmpty);
    });
  });

  group('aviso al registrar un gasto', () {
    // Presupuesto de 1.000 pesos.
    BudgetAlert? alert(int before, int added) =>
        BudgetCalculator.alertForExpense(
          limitCents: 100000,
          spentBeforeCents: before,
          addedCents: added,
        );

    test('un gasto que se queda dentro, sin acercarse, no avisa', () {
      expect(alert(0, 10000), isNull);
      expect(alert(20000, 30000), isNull);
    });

    test('avisa al llegar al 80 %, una sola vez', () {
      final reaching = alert(70000, 10000);

      expect(reaching, isNotNull);
      expect(reaching!.status, BudgetStatus.near);
      expect(reaching.spentAfterCents, 80000);
      expect(reaching.limitCents, 100000);

      // Ya estaba cerca: otro gasto que no se pasa no vuelve a avisar.
      expect(alert(80000, 5000), isNull);
      expect(alert(95000, 5000), isNull);
    });

    test('avisa al pasarse', () {
      final crossing = alert(90000, 20000);

      expect(crossing!.status, BudgetStatus.over);
      expect(crossing.spentAfterCents, 110000);
    });

    test('saltar de "bien" directo a pasarse avisa que se pasó', () {
      expect(alert(10000, 150000)!.status, BudgetStatus.over);
    });

    test('si ya estaba pasado, cada gasto nuevo lo recuerda', () {
      expect(alert(120000, 5000)!.status, BudgetStatus.over);
      expect(alert(120000, 5000)!.spentAfterCents, 125000);
    });

    test(
      'gastar justo el presupuesto avisa que está cerca, no que se pasó',
      () {
        expect(alert(50000, 50000)!.status, BudgetStatus.near);
      },
    );

    test('sin presupuesto o sin monto no hay aviso', () {
      expect(
        BudgetCalculator.alertForExpense(
          limitCents: 0,
          spentBeforeCents: 0,
          addedCents: 5000,
        ),
        isNull,
      );
      expect(alert(50000, 0), isNull);
    });
  });
}
