/// "2026-10-05": la fecha tal como se envía a la base de datos (sin hora).
String toDbDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
