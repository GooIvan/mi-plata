import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../summary/domain/month_summary.dart';
import '../../summary/presentation/summary_providers.dart';
import '../domain/budget_calculator.dart';
import 'budgets_providers.dart';

/// Los presupuestos de un mes frente a lo gastado, listos para mostrar.
///
/// Junta las reglas de presupuesto con los gastos por categoría del resumen
/// mensual: se vuelve a calcular solo cuando cambia cualquiera de los dos.
final budgetOverviewProvider = FutureProvider.autoDispose
    .family<BudgetOverview, DateTime>((ref, month) async {
      final rules = await ref.watch(budgetRulesProvider.future);
      final totals = await ref.watch(monthlyTotalsProvider(month).future);

      return BudgetCalculator.overview(
        rules: rules,
        month: month,
        expenseCentsByCategory: SummaryCalculator.forMonth(
          totals,
          month,
        ).expenseCentsByCategory,
      );
    });
