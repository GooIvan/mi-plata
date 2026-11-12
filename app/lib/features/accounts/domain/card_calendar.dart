/// Las fechas de una tarjeta de crédito: cuándo cierra el extracto (el corte) y
/// hasta cuándo hay que pagarlo.
///
/// Todas las fechas son días sin hora. Un día que el mes no tiene (un corte
/// "31" en abril) cae en el último día de ese mes.
class CardCalendar {
  const CardCalendar({required this.statementDay, required this.paymentDay})
    : assert(statementDay >= 1 && statementDay <= 31),
      assert(paymentDay >= 1 && paymentDay <= 31);

  /// El día del mes en que cierra el extracto.
  final int statementDay;

  /// El día del mes hasta el que hay que pagarlo.
  final int paymentDay;

  /// El corte del mes [month] del año [year].
  DateTime statementIn(int year, int month) =>
      _clamped(year, month, statementDay);

  /// El último corte que ya pasó; si hoy es día de corte, es hoy.
  DateTime lastStatement(DateTime today) {
    final day = _dateOnly(today);
    final thisMonth = statementIn(day.year, day.month);
    return thisMonth.isAfter(day)
        ? statementIn(day.year, day.month - 1)
        : thisMonth;
  }

  /// El primer corte después de hoy.
  DateTime nextStatement(DateTime today) {
    final day = _dateOnly(today);
    final thisMonth = statementIn(day.year, day.month);
    return thisMonth.isAfter(day)
        ? thisMonth
        : statementIn(day.year, day.month + 1);
  }

  /// La fecha límite para pagar el extracto que cierra en [statement]: el día de
  /// pago del mismo mes si viene después del corte, y si no, el del mes
  /// siguiente (un corte el 25 se paga a principios del mes que sigue).
  DateTime paymentFor(DateTime statement) {
    final sameMonth = _clamped(statement.year, statement.month, paymentDay);
    return sameMonth.isAfter(statement)
        ? sameMonth
        : _clamped(statement.year, statement.month + 1, paymentDay);
  }

  /// La próxima fecha límite de pago, contando hoy: la del último extracto si
  /// todavía no pasó, y si ya pasó, la del que cierra después.
  DateTime nextPayment(DateTime today) {
    final day = _dateOnly(today);
    final last = paymentFor(lastStatement(day));
    return last.isBefore(day) ? paymentFor(nextStatement(day)) : last;
  }

  /// El primer corte en que entra un gasto hecho en [date]: el de ese mismo día
  /// si es día de corte, y si no, el que sigue.
  DateTime statementOf(DateTime date) {
    final day = _dateOnly(date);
    final thisMonth = statementIn(day.year, day.month);
    return thisMonth.isBefore(day)
        ? statementIn(day.year, day.month + 1)
        : thisMonth;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Un día del mes, ajustado al último día cuando el mes es más corto. Acepta
  /// meses fuera de 1 a 12 (el 0 es diciembre del año anterior).
  static DateTime _clamped(int year, int month, int day) {
    final first = DateTime(year, month);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > lastDay ? lastDay : day);
  }
}
