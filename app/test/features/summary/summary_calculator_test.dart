import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/summary/domain/month_summary.dart';
import 'package:mi_plata/features/summary/domain/monthly_total.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

MonthlyTotal row(
  DateTime month,
  TransactionType type,
  double total, {
  String? category,
  String currency = 'COP',
  int movements = 1,
}) => MonthlyTotal(
  month: month,
  currency: currency,
  type: type,
  categoryId: category,
  total: total,
  movements: movements,
);

final oct = DateTime(2026, 10);
final sep = DateTime(2026, 9);
const income = TransactionType.income;
const expense = TransactionType.expense;

void main() {
  group('MonthlyTotal.fromJson', () {
    test('lee una fila de v_monthly_totals', () {
      final total = MonthlyTotal.fromJson({
        'user_id': 'u1',
        'month': '2026-10-01',
        'currency': 'COP',
        'type': 'expense',
        'category_id': null,
        'total': 120000.5,
        'movements': 3,
      });

      expect(total.month, DateTime(2026, 10));
      expect(total.type, expense);
      expect(total.categoryId, isNull);
      expect(total.total, 120000.5);
      expect(total.movements, 3);
    });
  });

  group('meses', () {
    test('monthStart deja solo el año y el mes', () {
      expect(SummaryCalculator.monthStart(DateTime(2026, 10, 22, 15)), oct);
    });

    test('addMonths cruza de año en los dos sentidos', () {
      expect(SummaryCalculator.addMonths(DateTime(2026, 11), 3), DateTime(2027, 2));
      expect(SummaryCalculator.addMonths(DateTime(2026, 2), -5), DateTime(2025, 9));
      expect(SummaryCalculator.addMonths(oct, 0), oct);
    });
  });

  group('forMonth', () {
    test('suma ingresos y gastos del mes, y calcula el balance', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, income, 3000000, category: 'salario'),
        row(oct, income, 500000, category: 'extra'),
        row(oct, expense, 1200000.5, category: 'mercado'),
        row(oct, expense, 300000, category: 'transporte'),
      ], oct);

      expect(summary.incomeCents, 350000000);
      expect(summary.expenseCents, 150000050);
      expect(summary.balanceCents, 199999950);
      expect(summary.movements, 4);
      expect(summary.isEmpty, isFalse);
    });

    test('ignora otros meses y otras monedas', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, expense, 100),
        row(sep, expense, 999),
        row(oct, expense, 777, currency: 'USD'),
      ], oct);

      expect(summary.expenseCents, 10000);
    });

    test('un mes sin movimientos queda en cero y vacío', () {
      final summary = SummaryCalculator.forMonth([row(sep, expense, 100)], oct);

      expect(summary.incomeCents, 0);
      expect(summary.expenseCents, 0);
      expect(summary.balanceCents, 0);
      expect(summary.isEmpty, isTrue);
      expect(summary.expenseByCategory, isEmpty);
    });

    test('un balance negativo es posible', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, income, 100),
        row(oct, expense, 350),
      ], oct);

      expect(summary.balanceCents, -25000);
    });

    test('suma en centavos sin error de punto flotante', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, expense, 0.1, category: 'a'),
        row(oct, expense, 0.2, category: 'b'),
      ], oct);

      expect(summary.expenseCents, 30);
    });
  });

  group('reparto por categoría', () {
    test('va de mayor a menor y las porciones suman 1', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, expense, 100, category: 'a'),
        row(oct, expense, 300, category: 'b'),
        row(oct, expense, 600, category: 'c'),
      ], oct);

      final shares = summary.expenseByCategory;
      expect(shares.map((s) => s.categoryId), ['c', 'b', 'a']);
      expect(shares.map((s) => s.share), [0.6, 0.3, 0.1]);
      expect(shares.fold(0.0, (sum, s) => sum + s.share), closeTo(1, 1e-9));
    });

    test('suma las filas de una misma categoría', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, expense, 100, category: 'a'),
        row(oct, expense, 50, category: 'a'),
      ], oct);

      expect(summary.expenseByCategory.single.cents, 15000);
      expect(summary.expenseByCategory.single.share, 1);
    });

    test('los movimientos sin categoría van aparte', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, expense, 700, category: 'a'),
        row(oct, expense, 300),
      ], oct);

      final uncategorized = summary.expenseByCategory.last;
      expect(uncategorized.kind, ShareKind.uncategorized);
      expect(uncategorized.categoryId, isNull);
      expect(uncategorized.share, 0.3);
    });

    test('ingresos y gastos se reparten por separado', () {
      final summary = SummaryCalculator.forMonth([
        row(oct, income, 1000, category: 'salario'),
        row(oct, expense, 400, category: 'mercado'),
      ], oct);

      expect(summary.incomeByCategory.single.categoryId, 'salario');
      expect(summary.expenseByCategory.single.categoryId, 'mercado');
    });

    test('con el mismo monto el orden es estable', () {
      final rows = [
        row(oct, expense, 100, category: 'b'),
        row(oct, expense, 100, category: 'a'),
      ];

      final first = SummaryCalculator.forMonth(rows, oct).expenseByCategory;
      final second =
          SummaryCalculator.forMonth(rows.reversed, oct).expenseByCategory;

      expect(first.map((s) => s.categoryId), ['a', 'b']);
      expect(second.map((s) => s.categoryId), ['a', 'b']);
    });

    group('agrupar las pequeñas en "Otras"', () {
      List<MonthlyTotal> categories(int count) => [
        for (var i = 0; i < count; i++)
          row(oct, expense, 1000.0 - i, category: 'c$i'),
      ];

      test('hasta ocho categorías se muestran todas', () {
        final shares =
            SummaryCalculator.forMonth(categories(8), oct).expenseByCategory;

        expect(shares, hasLength(8));
        expect(shares.any((s) => s.kind == ShareKind.other), isFalse);
      });

      test('con nueve se muestran siete y el resto va en "Otras"', () {
        final shares =
            SummaryCalculator.forMonth(categories(9), oct).expenseByCategory;

        expect(shares, hasLength(8));
        expect(shares.last.kind, ShareKind.other);
        expect(shares.last.categoryId, isNull);
        // Las dos más pequeñas: 1000-7 y 1000-8 (en centavos).
        expect(shares.last.cents, (993 + 992) * 100);
        expect(shares.fold(0.0, (sum, s) => sum + s.share), closeTo(1, 1e-9));
      });
    });
  });

  group('trend', () {
    test('devuelve seis meses, del más viejo al más reciente', () {
      final points = SummaryCalculator.trend([], oct);

      expect(points, hasLength(6));
      expect(points.first.month, DateTime(2026, 5));
      expect(points.last.month, oct);
    });

    test('un mes sin movimientos cuenta como cero', () {
      final points = SummaryCalculator.trend([
        row(oct, expense, 500),
        row(DateTime(2026, 7), income, 900),
      ], oct);

      expect(points.map((p) => p.incomeCents), [0, 0, 90000, 0, 0, 0]);
      expect(points.map((p) => p.expenseCents), [0, 0, 0, 0, 0, 50000]);
    });

    test('cruza el cambio de año', () {
      final points = SummaryCalculator.trend([], DateTime(2026, 2));

      expect(points.first.month, DateTime(2025, 9));
      expect(points.last.month, DateTime(2026, 2));
    });

    test('la cantidad de meses es configurable', () {
      expect(SummaryCalculator.trend([], oct, months: 3), hasLength(3));
    });
  });
}
