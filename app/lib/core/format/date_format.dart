import 'package:intl/intl.dart';

/// intl no trae fechas para es_CO; es_419 es el español de Latinoamérica.
const dateLocale = 'es_419';

/// "2026-10-05": la fecha tal como se envía a la base de datos (sin hora).
String toDbDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// "Hoy", "Ayer", "Lunes 12 de octubre" o, de otro año, "12 de octubre de 2025".
String formatDay(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final day = DateTime.utc(date.year, date.month, date.day);
  final current = DateTime.utc(now.year, now.month, now.day);

  final daysAgo = current.difference(day).inDays;
  if (daysAgo == 0) return 'Hoy';
  if (daysAgo == 1) return 'Ayer';

  final pattern = day.year == current.year
      ? "EEEE d 'de' MMMM"
      : "d 'de' MMMM 'de' y";
  return toBeginningOfSentenceCase(DateFormat(pattern, dateLocale).format(day))!;
}

/// "Octubre 2026".
String formatMonth(DateTime month) => toBeginningOfSentenceCase(
  DateFormat('MMMM y', dateLocale).format(month),
)!;

/// "octubre", para frases como "más que en septiembre".
String formatMonthName(DateTime month) =>
    DateFormat('MMMM', dateLocale).format(month);

/// "oct", para ejes de gráficos.
String formatMonthShort(DateTime month) =>
    DateFormat('MMM', dateLocale).format(month).replaceAll('.', '');

/// "12 oct", para fechas cortas en listas.
String formatDayMonth(DateTime date) =>
    DateFormat('d MMM', dateLocale).format(date).replaceAll('.', '');

/// "12 de octubre de 2026".
String formatFullDate(DateTime date) =>
    DateFormat("d 'de' MMMM 'de' y", dateLocale).format(date);
