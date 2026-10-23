import '../../transactions/domain/transaction_type.dart';
import 'monthly_total.dart';

/// De qué es una porción del reparto por categorías.
enum ShareKind {
  /// Una categoría concreta (ver `categoryId`).
  category,

  /// Movimientos sin categoría.
  uncategorized,

  /// Las categorías más pequeñas, agrupadas para no saturar la lista.
  other,
}

/// Cuánto representa una categoría dentro del total de ingresos o de gastos.
class CategoryShare {
  const CategoryShare({
    required this.kind,
    this.categoryId,
    required this.cents,
    required this.share,
  });

  final ShareKind kind;
  final String? categoryId;
  final int cents;

  /// Fracción del total, de 0 a 1.
  final double share;
}

/// El ingreso y el gasto de un mes.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime month;
  final int incomeCents;
  final int expenseCents;
}

/// El resumen de un mes: totales y reparto por categoría.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.incomeCentsByCategory,
    required this.expenseCentsByCategory,
    required this.movements,
  });

  final DateTime month;
  final int incomeCents;
  final int expenseCents;

  /// El reparto ya ordenado y con las pequeñas agrupadas en "Otras".
  final List<CategoryShare> incomeByCategory;
  final List<CategoryShare> expenseByCategory;

  /// Los montos de cada categoría sin agrupar (la clave nula es "sin
  /// categoría"): sirven para comparar una categoría con la del mes anterior.
  final Map<String?, int> incomeCentsByCategory;
  final Map<String?, int> expenseCentsByCategory;
  final int movements;

  int get balanceCents => incomeCents - expenseCents;
  bool get isEmpty => movements == 0;
}

/// Cómo cambió una cifra respecto a otra (por ejemplo, frente al mes anterior).
class Change {
  const Change({required this.deltaCents, required this.fraction});

  /// Compara [current] con [previous], ambos en centavos.
  factory Change.between(int current, int previous) => Change(
    deltaCents: current - previous,
    fraction: previous == 0 ? null : (current - previous) / previous,
  );

  /// Cuánto subió (positivo) o bajó (negativo).
  final int deltaCents;

  /// La variación sobre lo anterior: 0,12 es un 12 % más. Es null cuando antes
  /// era cero, porque entonces no existe un porcentaje.
  final double? fraction;

  bool get isUp => deltaCents > 0;
  bool get isDown => deltaCents < 0;
  bool get isSame => deltaCents == 0;
}

/// A qué ritmo se está gastando en un mes.
class SpendingPace {
  const SpendingPace({
    required this.dailyAverageCents,
    required this.daysCounted,
    required this.daysInMonth,
    this.projectedCents,
  });

  /// El gasto promedio de cada día.
  final int dailyAverageCents;

  /// Los días que se tuvieron en cuenta: los transcurridos si el mes sigue en
  /// curso, o todos si ya terminó.
  final int daysCounted;
  final int daysInMonth;

  /// Cuánto sumaría el mes a este ritmo. Solo existe mientras el mes sigue en
  /// curso y ya pasaron unos días: con uno o dos, la proyección engaña.
  final int? projectedCents;
}

/// Calcula el resumen a partir de las filas de `v_monthly_totals`.
///
/// Todo se suma en centavos enteros para no acumular error de punto
/// flotante. De momento solo se resume una moneda (el peso colombiano).
class SummaryCalculator {
  const SummaryCalculator._();

  static const currency = 'COP';

  /// Cuántas categorías se muestran antes de agrupar el resto en "Otras".
  static const maxCategories = 7;

  static int _cents(double amount) => (amount * 100).round();

  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime addMonths(DateTime month, int months) =>
      DateTime(month.year, month.month + months);

  /// Lo que pasó en [month].
  static MonthSummary forMonth(Iterable<MonthlyTotal> rows, DateTime month) {
    final start = monthStart(month);
    final ofMonth = rows
        .where((row) => row.currency == currency && row.month == start)
        .toList();

    final income = _byCategory(ofMonth, TransactionType.income);
    final expense = _byCategory(ofMonth, TransactionType.expense);

    return MonthSummary(
      month: start,
      incomeCents: _sum(ofMonth, TransactionType.income),
      expenseCents: _sum(ofMonth, TransactionType.expense),
      incomeByCategory: _shares(income),
      expenseByCategory: _shares(expense),
      incomeCentsByCategory: income,
      expenseCentsByCategory: expense,
      movements: ofMonth.fold(0, (total, row) => total + row.movements),
    );
  }

  /// Los días que tiene [month].
  static int daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// El ritmo de gasto de [summary], visto desde [today].
  ///
  /// Si el mes está en curso, el promedio cuenta solo los días que han pasado y
  /// se proyecta a fin de mes (a partir del tercer día); si ya terminó, el
  /// promedio es sobre todos sus días y no hay nada que proyectar.
  static SpendingPace pace(MonthSummary summary, DateTime today) {
    final days = daysInMonth(summary.month);
    final isCurrent = monthStart(today) == summary.month;
    final counted = isCurrent ? today.day.clamp(1, days) : days;
    final average = (summary.expenseCents / counted).round();

    return SpendingPace(
      dailyAverageCents: average,
      daysCounted: counted,
      daysInMonth: days,
      projectedCents: isCurrent && counted >= minDaysToProject
          ? (summary.expenseCents * days / counted).round()
          : null,
    );
  }

  /// Desde qué día del mes se proyecta el gasto a fin de mes.
  static const minDaysToProject = 3;

  /// Ingresos y gastos de los [months] meses que terminan en [end], del más
  /// viejo al más reciente. Un mes sin movimientos cuenta como cero.
  static List<MonthPoint> trend(
    Iterable<MonthlyTotal> rows,
    DateTime end, {
    int months = 6,
  }) {
    final last = monthStart(end);
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final summary = forMonth(rows, addMonths(last, -i));
          return MonthPoint(
            month: summary.month,
            incomeCents: summary.incomeCents,
            expenseCents: summary.expenseCents,
          );
        }(),
    ];
  }

  static int _sum(List<MonthlyTotal> rows, TransactionType type) => rows
      .where((row) => row.type == type)
      .fold(0, (total, row) => total + _cents(row.total));

  /// Lo de cada categoría de [type], en centavos (la clave nula es "sin
  /// categoría").
  static Map<String?, int> _byCategory(
    List<MonthlyTotal> rows,
    TransactionType type,
  ) {
    final byCategory = <String?, int>{};
    for (final row in rows.where((row) => row.type == type)) {
      byCategory.update(
        row.categoryId,
        (cents) => cents + _cents(row.total),
        ifAbsent: () => _cents(row.total),
      );
    }
    return byCategory;
  }

  /// El reparto por categoría, de mayor a menor. Las más pequeñas se agrupan
  /// en una sola porción "Otras" después de [maxCategories].
  static List<CategoryShare> _shares(Map<String?, int> byCategory) {
    final total = byCategory.values.fold(0, (sum, cents) => sum + cents);
    if (total <= 0) return const [];

    final sorted = byCategory.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        // Con el mismo monto, un orden estable: primero las que tienen id.
        return byAmount != 0 ? byAmount : (a.key ?? '').compareTo(b.key ?? '');
      });

    CategoryShare share(MapEntry<String?, int> entry) => CategoryShare(
      kind: entry.key == null ? ShareKind.uncategorized : ShareKind.category,
      categoryId: entry.key,
      cents: entry.value,
      share: entry.value / total,
    );

    // Con una más de la cuenta no vale la pena agrupar: "Otras" sería una sola.
    if (sorted.length <= maxCategories + 1) return sorted.map(share).toList();

    final shown = sorted.take(maxCategories).map(share).toList();
    final restCents = sorted
        .skip(maxCategories)
        .fold(0, (sum, entry) => sum + entry.value);
    return [
      ...shown,
      CategoryShare(
        kind: ShareKind.other,
        cents: restCents,
        share: restCents / total,
      ),
    ];
  }
}
