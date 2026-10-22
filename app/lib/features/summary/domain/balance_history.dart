import 'dart:math' as math;

import '../../accounts/domain/account.dart';
import 'month_summary.dart';

/// Cuánto entró (positivo) o salió (negativo) de una cuenta en un mes: una
/// fila de `v_monthly_account_flows`.
class AccountFlow {
  const AccountFlow({
    required this.month,
    required this.accountId,
    required this.currency,
    required this.cents,
  });

  factory AccountFlow.fromJson(Map<String, dynamic> json) => AccountFlow(
    month: DateTime.parse(json['month'] as String),
    accountId: json['account_id'] as String,
    currency: json['currency'] as String,
    cents: ((json['flow'] as num) * 100).round(),
  );

  /// El primer día del mes.
  final DateTime month;
  final String accountId;
  final String currency;
  final int cents;
}

/// El dinero total al cierre de un mes.
class BalancePoint {
  const BalancePoint({required this.month, required this.cents});

  final DateTime month;
  final int cents;
}

/// Reconstruye cuánto dinero había al cierre de cada mes.
///
/// No hay saldos históricos guardados: el saldo de una cuenta se calcula como
/// su saldo inicial más todo lo que entró y salió. Aquí se hace la misma suma,
/// cortada al final de cada mes, y en centavos enteros para no acumular error.
class BalanceHistory {
  const BalanceHistory._();

  /// El dinero total, mes a mes, de los [months] meses que terminan en [end]
  /// (del más viejo al más reciente).
  ///
  /// Solo cuentan las cuentas activas de [currency], igual que el total del
  /// panel. Lo que ocurra después de [end] no entra.
  static List<BalancePoint> compute({
    required Iterable<Account> accounts,
    required Iterable<AccountFlow> flows,
    required DateTime end,
    int months = 6,
    String currency = 'COP',
  }) {
    final last = SummaryCalculator.monthStart(end);
    final first = SummaryCalculator.addMonths(last, -(months - 1));

    final active = accounts
        .where((account) => !account.isArchived && account.currency == currency)
        .toList();
    final ids = {for (final account in active) account.id};
    final relevant = flows
        .where((flow) => flow.currency == currency && ids.contains(flow.accountId))
        .toList();

    // Lo que había antes del primer mes de la ventana: los saldos iniciales y
    // todo lo ocurrido hasta entonces.
    var running = active.fold(
      0,
      (sum, account) => sum + (account.initialBalance * 100).round(),
    );
    running += relevant
        .where((flow) => flow.month.isBefore(first))
        .fold(0, (sum, flow) => sum + flow.cents);

    final points = <BalancePoint>[];
    for (var i = 0; i < months; i++) {
      final month = SummaryCalculator.addMonths(first, i);
      running += relevant
          .where((flow) => flow.month == month)
          .fold(0, (sum, flow) => sum + flow.cents);
      points.add(BalancePoint(month: month, cents: running));
    }
    return points;
  }
}

/// El rango del eje vertical de un gráfico de línea.
///
/// A diferencia de las barras, una línea no tiene que partir de cero: si el
/// dinero se mueve entre 4,4 y 4,6 millones, el eje se ajusta a eso para que
/// el cambio se vea. Si todos los valores son positivos, nunca baja de cero.
class LineAxis {
  const LineAxis({required this.min, required this.max, required this.step});

  final double min;
  final double max;
  final double step;

  /// Un rango con cifras redondas (paso de 1, 2, 2,5 o 5 por una potencia de
  /// diez) que abarca de [lowest] a [highest] con unas pocas marcas.
  factory LineAxis.forValues(double lowest, double highest) {
    var low = lowest;
    var high = highest;

    // Todos los valores iguales: se da un poco de aire para que haya eje.
    if (low == high) {
      final pad = high == 0 ? 1000.0 : high.abs() * 0.1;
      low -= pad;
      high += pad;
    }

    final margin = (high - low) * 0.1;
    var floor = low - margin;
    final ceiling = high + margin;
    if (lowest >= 0 && floor < 0) floor = 0;

    final range = ceiling - floor;
    var power = math.pow(10, (math.log(range) / math.ln10).floor() - 1);
    while (true) {
      for (final factor in const [1.0, 2.0, 2.5, 5.0]) {
        final step = factor * power;
        if (range / step - 1e-9 <= 5) {
          return LineAxis(
            min: (floor / step).floorToDouble() * step,
            max: (ceiling / step).ceilToDouble() * step,
            step: step,
          );
        }
      }
      power *= 10;
    }
  }
}
