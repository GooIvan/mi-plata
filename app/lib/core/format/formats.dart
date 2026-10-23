import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';

/// Los idiomas para los que hay que cargar datos de fecha al arrancar.
const dateLocales = ['es_419', 'en_US'];

/// Montos y fechas escritos como se acostumbra en el idioma de la app.
///
/// Lo que depende de la costumbre (dónde va el símbolo, qué separa miles y
/// decimales, el orden de día y mes) se resuelve aquí; los textos sueltos
/// ("Hoy", "Ayer") salen de las traducciones.
class Formats {
  const Formats(this.l10n);

  final AppLocalizations l10n;

  bool get _english => l10n.localeName == 'en';

  /// intl no trae números ni fechas para es_CO; las fechas usan es_419, el
  /// español de Latinoamérica.
  String get _numberLocale => _english ? 'en_US' : 'es_CO';
  String get _dateLocale => _english ? 'en_US' : 'es_419';

  /// El separador de decimales que se escribe en los campos de monto.
  String get decimalSeparator => _english ? '.' : ',';

  /// Una cifra corta para ejes de gráficos: "$1,5 M", "$500 mil", "-$500 mil".
  String compactMoney(double value) {
    final amount = NumberFormat.compact(
      locale: _numberLocale,
    ).format(value.abs());
    return value < 0 ? '-\$$amount' : '\$$amount';
  }

  /// Da formato de moneda: "$1.500.000" (con centavos solo si los hay).
  ///
  /// El patrón es explícito porque el de `es_CO` en intl pone el símbolo al
  /// final ("1.500.000 $"), y en Colombia se escribe antes.
  String money(double value, {String currency = 'COP'}) {
    // Se redondea a centavos para que una suma como 0.1 + 0.2 no muestre ruido.
    final rounded = (value * 100).round() / 100;
    final hasCents = rounded != rounded.roundToDouble();

    return NumberFormat.currency(
      locale: _numberLocale,
      symbol: currency == 'COP' ? r'$' : '$currency ',
      customPattern: '¤#,##0.00',
      decimalDigits: hasCents ? 2 : 0,
    ).format(rounded);
  }

  /// "Hoy", "Ayer", "Lunes 12 de octubre" o, de otro año, "12 de octubre de 2025".
  String day(DateTime date, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime.utc(date.year, date.month, date.day);
    final current = DateTime.utc(now.year, now.month, now.day);

    final daysAgo = current.difference(day).inDays;
    if (daysAgo == 0) return l10n.today;
    if (daysAgo == 1) return l10n.yesterday;

    final thisYear = day.year == current.year;
    final pattern = _english
        ? (thisYear ? 'EEEE, MMMM d' : 'MMMM d, y')
        : (thisYear ? "EEEE d 'de' MMMM" : "d 'de' MMMM 'de' y");
    return toBeginningOfSentenceCase(DateFormat(pattern, _dateLocale).format(day))!;
  }

  /// "Octubre 2026".
  String month(DateTime month) => toBeginningOfSentenceCase(
    DateFormat('MMMM y', _dateLocale).format(month),
  )!;

  /// "octubre", para frases como "más que en septiembre".
  String monthName(DateTime month) =>
      DateFormat('MMMM', _dateLocale).format(month);

  /// "oct", para ejes de gráficos.
  String monthShort(DateTime month) =>
      DateFormat('MMM', _dateLocale).format(month).replaceAll('.', '');

  /// "12 oct" ("Oct 12" en inglés), para fechas cortas en listas.
  String dayMonth(DateTime date) => DateFormat(
    _english ? 'MMM d' : 'd MMM',
    _dateLocale,
  ).format(date).replaceAll('.', '');

  /// "12 de octubre de 2026".
  String fullDate(DateTime date) => DateFormat(
    _english ? 'MMMM d, y' : "d 'de' MMMM 'de' y",
    _dateLocale,
  ).format(date);
}

extension FormatsContext on BuildContext {
  /// Montos y fechas en el idioma actual.
  Formats get formats => Formats(l10n);
}
