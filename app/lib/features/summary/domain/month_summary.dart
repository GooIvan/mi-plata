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
    required this.movements,
  });

  final DateTime month;
  final int incomeCents;
  final int expenseCents;
  final List<CategoryShare> incomeByCategory;
  final List<CategoryShare> expenseByCategory;
  final int movements;

  int get balanceCents => incomeCents - expenseCents;
  bool get isEmpty => movements == 0;
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

    return MonthSummary(
      month: start,
      incomeCents: _sum(ofMonth, TransactionType.income),
      expenseCents: _sum(ofMonth, TransactionType.expense),
      incomeByCategory: _shares(ofMonth, TransactionType.income),
      expenseByCategory: _shares(ofMonth, TransactionType.expense),
      movements: ofMonth.fold(0, (total, row) => total + row.movements),
    );
  }

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

  /// El reparto de [type] por categoría, de mayor a menor. Las más pequeñas
  /// se agrupan en una sola porción "Otras" después de [maxCategories].
  static List<CategoryShare> _shares(
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
