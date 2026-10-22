import 'amount_parser.dart';

/// Reglas del formulario de cuentas. Los mensajes llegan al usuario.
class AccountValidators {
  const AccountValidators._();

  static const maxNameLength = 40;

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Ponle un nombre a la cuenta';
    if (name.length > maxNameLength) {
      return 'Usa $maxNameLength caracteres o menos';
    }
    return null;
  }

  static String? initialBalance(String? value) {
    if (AmountParser.parse(value) == null) {
      return 'Monto no válido. Ejemplo: 1.500.000 o 1500,50';
    }
    return null;
  }
}
