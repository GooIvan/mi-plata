import 'package:intl/intl.dart';

/// intl no trae fechas para es_CO; es_419 es el español de Latinoamérica.
const dateLocale = 'es_419';

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

/// "12 de octubre de 2026".
String formatFullDate(DateTime date) =>
    DateFormat("d 'de' MMMM 'de' y", dateLocale).format(date);
