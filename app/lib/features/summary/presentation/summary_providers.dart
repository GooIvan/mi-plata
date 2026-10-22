import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/summary_repository.dart';
import '../domain/balance_history.dart';
import '../domain/month_summary.dart';
import '../domain/monthly_total.dart';

/// Cuántos meses muestra el gráfico de tendencia.
const trendMonths = 6;

final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(supabaseClientProvider)),
);

/// Lo que entró y salió de cada cuenta cada mes, de todo el historial. No
/// depende del mes que se mira: así cambiar de mes no vuelve a consultarlo.
final accountFlowsProvider = FutureProvider.autoDispose<List<AccountFlow>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(summaryRepositoryProvider).fetchAccountFlows();
});

/// Los totales del mes pedido y de los cinco anteriores, en una sola consulta:
/// con eso se arman tanto el resumen del mes como la tendencia.
///
/// Se pide por mes (el primer día) y se vuelve a pedir cuando cambia un
/// movimiento (ver [ledgerRevisionProvider]).
final monthlyTotalsProvider = FutureProvider.autoDispose
    .family<List<MonthlyTotal>, DateTime>((ref, month) {
      ref.watch(ledgerRevisionProvider);
      return ref
          .watch(summaryRepositoryProvider)
          .fetchMonthlyTotals(
            from: SummaryCalculator.addMonths(month, -(trendMonths - 1)),
            to: month,
          );
    });
