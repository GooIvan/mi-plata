/// Convierte lo que escribe el usuario en un decimal exacto, como texto.
///
/// Usa el formato colombiano: el punto separa miles y la coma los decimales.
/// "1.500.000" -> "1500000", "1.500,50" -> "1500.50", "-200000" -> "-200000".
class AmountParser {
  const AmountParser._();

  /// Dígitos enteros que caben en `numeric(14, 2)`.
  static const maxIntegerDigits = 12;

  static final _ignored = RegExp(r'[\s$]');
  static final _pattern = RegExp(r'^(-)?(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?$');

  /// Devuelve null si el texto no es un monto válido. Un texto vacío vale 0.
  static String? parse(String? input) {
    final text = (input ?? '').replaceAll(_ignored, '');
    if (text.isEmpty) return '0';

    final match = _pattern.firstMatch(text);
    if (match == null) return null;

    final integer = match.group(2)!.replaceAll('.', '');
    if (integer.length > maxIntegerDigits) return null;

    final sign = match.group(1) ?? '';
    final decimals = match.group(3);
    return '$sign$integer${decimals == null ? '' : '.$decimals'}';
  }

  /// Texto para mostrar un monto en un campo editable ("1500000" o "1500,50").
  static String toInput(double value) {
    final fixed = value.toStringAsFixed(2);
    final trimmed = fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed;
    return trimmed.replaceAll('.', ',');
  }
}
