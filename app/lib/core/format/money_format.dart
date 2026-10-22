import 'package:intl/intl.dart';

/// Da formato de moneda colombiano: "$1.500.000" (con centavos solo si los hay).
///
/// El patrón es explícito porque el de `es_CO` en intl pone el símbolo al
/// final ("1.500.000 $"), y en Colombia se escribe antes.
String formatMoney(double value, {String currency = 'COP'}) {
  final hasCents = value.roundToDouble() != value;
  return NumberFormat.currency(
    locale: 'es_CO',
    symbol: currency == 'COP' ? r'$' : '$currency ',
    customPattern: '¤#,##0.00',
    decimalDigits: hasCents ? 2 : 0,
  ).format(value);
}
