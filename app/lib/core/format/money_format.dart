import 'package:intl/intl.dart';

/// Una cifra corta para ejes de gráficos: "$1,5 M", "$500 mil".
String formatCompactMoney(double value) =>
    '\$${NumberFormat.compact(locale: 'es_CO').format(value)}';

/// Da formato de moneda colombiano: "$1.500.000" (con centavos solo si los hay).
///
/// El patrón es explícito porque el de `es_CO` en intl pone el símbolo al
/// final ("1.500.000 $"), y en Colombia se escribe antes.
String formatMoney(double value, {String currency = 'COP'}) {
  // Se redondea a centavos para que una suma como 0.1 + 0.2 no muestre ruido.
  final rounded = (value * 100).round() / 100;
  final hasCents = rounded != rounded.roundToDouble();

  return NumberFormat.currency(
    locale: 'es_CO',
    symbol: currency == 'COP' ? r'$' : '$currency ',
    customPattern: '¤#,##0.00',
    decimalDigits: hasCents ? 2 : 0,
  ).format(rounded);
}
