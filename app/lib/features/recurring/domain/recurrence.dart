/// La unidad de cada cuánto se repite un pago.
enum RecurrenceUnit {
  week,
  month,
  year;

  /// Valor guardado en la columna `unit` de la base de datos.
  String get dbValue => name;

  static RecurrenceUnit fromDb(String value) =>
      RecurrenceUnit.values.firstWhere((unit) => unit.name == value);
}

/// Cada cuánto se repite un pago: "cada 2 semanas", "cada mes", "cada año".
class Recurrence {
  const Recurrence(this.every, this.unit);

  final int every;
  final RecurrenceUnit unit;

  static const weekly = Recurrence(1, RecurrenceUnit.week);
  static const biweekly = Recurrence(2, RecurrenceUnit.week);
  static const monthly = Recurrence(1, RecurrenceUnit.month);
  static const bimonthly = Recurrence(2, RecurrenceUnit.month);
  static const quarterly = Recurrence(3, RecurrenceUnit.month);
  static const semiannual = Recurrence(6, RecurrenceUnit.month);
  static const yearly = Recurrence(1, RecurrenceUnit.year);

  /// Las frecuencias que ofrece la app. La base de datos admite cualquier
  /// cantidad de semanas, meses o años.
  static const presets = [
    weekly,
    biweekly,
    monthly,
    bimonthly,
    quarterly,
    semiannual,
    yearly,
  ];

  /// La fecha que sigue a [date]. En meses y años se conserva el día
  /// [anchorDay] (o el último del mes si no existe): un pago del 31 cae el 28
  /// en febrero y vuelve al 31 en marzo. Es la misma cuenta que hace la función
  /// `recurring_advance` de la base de datos.
  DateTime advance(DateTime date, {required int anchorDay}) {
    if (unit == RecurrenceUnit.week) {
      return DateTime(date.year, date.month, date.day + 7 * every);
    }

    final months = every * (unit == RecurrenceUnit.year ? 12 : 1);
    final first = DateTime(date.year, date.month + months);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(
      first.year,
      first.month,
      anchorDay < lastDay ? anchorDay : lastDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.every == every && other.unit == unit;

  @override
  int get hashCode => Object.hash(every, unit);
}
