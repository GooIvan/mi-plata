import '../../../core/format/formats.dart';

/// Convierte lo que escribe el usuario en un decimal exacto, como texto.
///
/// Sigue la costumbre del idioma: en español el punto separa miles y la coma
/// los decimales; en inglés, al revés.
/// "1.500.000" -> "1500000", "1.500,50" -> "1500.50", "-200000" -> "-200000".
class AmountParser {
  const AmountParser._();

  /// Dígitos enteros que caben en `numeric(14, 2)`.
  static const maxIntegerDigits = 12;

  static final _ignored = RegExp(r'[\s$]');

  /// Devuelve null si el texto no es un monto válido. Un texto vacío vale 0.
  ///
  /// Los montos llevan hasta dos decimales y doce dígitos enteros; las tasas de
  /// cambio piden más decimales y menos enteros (ver [maxDecimals] y
  /// [integerDigits]).
  static String? parse(
    String? input,
    Formats formats, {
    int maxDecimals = 2,
    int integerDigits = maxIntegerDigits,
  }) {
    final text = (input ?? '').replaceAll(_ignored, '');
    if (text.isEmpty) return '0';

    final decimal = RegExp.escape(formats.decimalSeparator);
    final group = formats.decimalSeparator == ',' ? '.' : ',';
    final pattern = RegExp(
      '^(-)?(\\d{1,3}(?:${RegExp.escape(group)}\\d{3})+|\\d+)'
      '(?:$decimal(\\d{1,$maxDecimals}))?\$',
    );

    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final integer = match.group(2)!.replaceAll(group, '');
    if (integer.length > integerDigits) return null;

    final sign = match.group(1) ?? '';
    final decimals = match.group(3);
    return '$sign$integer${decimals == null ? '' : '.$decimals'}';
  }

  /// Texto para mostrar un monto en un campo editable ("1500000" o "1500,50").
  static String toInput(double value, Formats formats) {
    final fixed = value.toStringAsFixed(2);
    final trimmed = fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed;
    return trimmed.replaceAll('.', formats.decimalSeparator);
  }
}
