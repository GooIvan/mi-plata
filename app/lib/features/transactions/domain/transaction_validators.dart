import '../../accounts/domain/amount_parser.dart';

/// Reglas del formulario de movimientos. Los mensajes llegan al usuario.
class TransactionValidators {
  const TransactionValidators._();

  static const maxDescriptionLength = 200;

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa el monto';

    final parsed = AmountParser.parse(value);
    if (parsed == null) return 'Monto no válido. Ejemplo: 1.500.000 o 1500,50';
    if (parsed.startsWith('-')) return 'El monto no puede ser negativo';
    if (double.parse(parsed) == 0) return 'El monto debe ser mayor que cero';
    return null;
  }

  static String? description(String? value) {
    if ((value?.trim().length ?? 0) > maxDescriptionLength) {
      return 'Usa $maxDescriptionLength caracteres o menos';
    }
    return null;
  }
}
