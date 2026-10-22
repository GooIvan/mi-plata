import '../../summary/domain/month_summary.dart';
import 'budget_rule.dart';

/// Cómo va el gasto frente al presupuesto.
enum BudgetStatus {
  /// Dentro del presupuesto, con margen.
  ok,

  /// Ya se usó el 80 % o más, pero sin pasarse.
  near,

  /// Se gastó más de lo presupuestado.
  over,
}

/// Cuánto se lleva gastado de lo presupuestado en una categoría.
class BudgetProgress {
  const BudgetProgress({
    required this.categoryId,
    required this.limitCents,
    required this.spentCents,
  });

  final String categoryId;
  final int limitCents;
  final int spentCents;

  /// Lo que queda (negativo si se pasó).
  int get remainingCents => limitCents - spentCents;

  /// Qué parte del presupuesto se usó; supera 1 si se pasó.
  double get fraction => limitCents == 0 ? 0 : spentCents / limitCents;

  BudgetStatus get status => BudgetCalculator.statusOf(spentCents, limitCents);
}

/// Lo gastado en una categoría que no tiene presupuesto ([categoryId] nulo es
/// "sin categoría").
class UnbudgetedSpending {
  const UnbudgetedSpending({
    required this.categoryId,
    required this.spentCents,
  });

  final String? categoryId;
  final int spentCents;
}

/// El estado de los presupuestos de un mes.
class BudgetOverview {
  const BudgetOverview({required this.budgeted, required this.unbudgeted});

  /// Las categorías con presupuesto: las que se pasaron o van cerca, primero.
  final List<BudgetProgress> budgeted;

  /// Lo que se gastó fuera de los presupuestos, de mayor a menor.
  final List<UnbudgetedSpending> unbudgeted;

  bool get hasBudgets => budgeted.isNotEmpty;

  int get totalLimitCents => budgeted.fold(0, (sum, b) => sum + b.limitCents);
  int get totalSpentCents => budgeted.fold(0, (sum, b) => sum + b.spentCents);
  int get totalRemainingCents => totalLimitCents - totalSpentCents;

  double get fraction =>
      totalLimitCents == 0 ? 0 : totalSpentCents / totalLimitCents;

  /// El estado del conjunto: lo gastado frente a todo lo presupuestado.
  BudgetStatus get status =>
      BudgetCalculator.statusOf(totalSpentCents, totalLimitCents);
}

/// Un aviso al registrar un gasto que acerca o pasa un presupuesto.
class BudgetAlert {
  const BudgetAlert({
    required this.status,
    required this.limitCents,
    required this.spentAfterCents,
  });

  /// [BudgetStatus.near] o [BudgetStatus.over]; nunca `ok`.
  final BudgetStatus status;
  final int limitCents;

  /// Lo que quedará gastado en la categoría con este gasto.
  final int spentAfterCents;
}

/// Calcula los presupuestos. Todo en centavos enteros.
class BudgetCalculator {
  const BudgetCalculator._();

  /// A partir de qué fracción usada se considera "cerca": el 80 %.
  static const nearPercent = 80;

  /// El estado de [spent] frente a [limit], comparado con enteros: sin
  /// redondeos de coma flotante en el límite exacto.
  static BudgetStatus statusOf(int spent, int limit) {
    if (spent > limit) return BudgetStatus.over;
    if (spent * 100 >= limit * nearPercent) return BudgetStatus.near;
    return BudgetStatus.ok;
  }

  /// El presupuesto que rige para cada categoría en [month]: el de la regla
  /// más reciente que no sea posterior a ese mes. Las categorías cuya regla
  /// vigente es cero (o que aún no tenían ninguna) no aparecen.
  static Map<String, int> effectiveLimits(
    Iterable<BudgetRule> rules,
    DateTime month,
  ) {
    final target = SummaryCalculator.monthStart(month);
    final latest = <String, BudgetRule>{};

    for (final rule in rules) {
      if (rule.month.isAfter(target)) continue;
      final current = latest[rule.categoryId];
      if (current == null || rule.month.isAfter(current.month)) {
        latest[rule.categoryId] = rule;
      }
    }

    return {
      for (final entry in latest.entries)
        if (entry.value.cents > 0) entry.key: entry.value.cents,
    };
  }

  /// Los presupuestos de [month] frente a lo gastado ([expenseCentsByCategory],
  /// con la clave nula para "sin categoría").
  static BudgetOverview overview({
    required Iterable<BudgetRule> rules,
    required DateTime month,
    required Map<String?, int> expenseCentsByCategory,
  }) {
    final limits = effectiveLimits(rules, month);

    final budgeted = [
      for (final entry in limits.entries)
        BudgetProgress(
          categoryId: entry.key,
          limitCents: entry.value,
          spentCents: expenseCentsByCategory[entry.key] ?? 0,
        ),
    ]..sort(_urgentFirst);

    final unbudgeted = [
      for (final entry in expenseCentsByCategory.entries)
        if (entry.value > 0 &&
            (entry.key == null || !limits.containsKey(entry.key)))
          UnbudgetedSpending(categoryId: entry.key, spentCents: entry.value),
    ]..sort((a, b) => b.spentCents.compareTo(a.spentCents));

    return BudgetOverview(budgeted: budgeted, unbudgeted: unbudgeted);
  }

  /// Los más pasados o cerca del límite, primero; con igual avance, por id.
  static int _urgentFirst(BudgetProgress a, BudgetProgress b) {
    final byFraction = b.fraction.compareTo(a.fraction);
    return byFraction != 0 ? byFraction : a.categoryId.compareTo(b.categoryId);
  }

  /// El aviso que corresponde a un gasto de [addedCents] en una categoría con
  /// presupuesto [limitCents] que ya lleva [spentBeforeCents], o null si no
  /// hay nada que decir.
  ///
  /// Avisa siempre que el gasto deja la categoría por encima del presupuesto
  /// (se acaba de pasar o ya estaba pasada), y avisa una sola vez al llegar al
  /// 80 %: el momento en que todavía se puede corregir el rumbo.
  static BudgetAlert? alertForExpense({
    required int limitCents,
    required int spentBeforeCents,
    required int addedCents,
  }) {
    if (limitCents <= 0 || addedCents <= 0) return null;

    final after = spentBeforeCents + addedCents;
    final before = statusOf(spentBeforeCents, limitCents);
    final status = statusOf(after, limitCents);

    if (status == BudgetStatus.over ||
        (status == BudgetStatus.near && before == BudgetStatus.ok)) {
      return BudgetAlert(
        status: status,
        limitCents: limitCents,
        spentAfterCents: after,
      );
    }
    return null;
  }
}
