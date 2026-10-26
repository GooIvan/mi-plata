import '../../../core/format/formats.dart';
import '../../accounts/domain/amount_parser.dart';

/// Lee y escribe tasas de cambio con el formato del idioma.
///
/// A diferencia de un monto, una tasa admite hasta seis decimales (0,00025) y
/// tiene que ser mayor que cero.
class RateParser {
  const RateParser._();

  static const maxDecimals = 6;

  /// Dígitos enteros que caben en `numeric(20, 10)`.
  static const maxIntegerDigits = 10;

  /// La tasa como decimal exacto en texto, o null si no es una tasa válida
  /// (vacía, con otro formato, cero o negativa).
  static String? parse(String? input, Formats formats) {
    if (input == null || input.trim().isEmpty) return null;
    final parsed = AmountParser.parse(
      input,
      formats,
      maxDecimals: maxDecimals,
      integerDigits: maxIntegerDigits,
    );
    if (parsed == null || parsed.startsWith('-')) return null;
    return double.parse(parsed) > 0 ? parsed : null;
  }

  /// La tasa para mostrarla en un campo editable, sin ceros de sobra.
  static String toInput(double rate, Formats formats) {
    var text = rate.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text.replaceAll('.', formats.decimalSeparator);
  }
}
