/// Un total pasado a la moneda base, con las monedas que se quedaron fuera
/// porque no tienen tasa de cambio.
class ConvertedTotal {
  const ConvertedTotal({required this.cents, this.missing = const {}});

  /// La suma, en centavos de la moneda base, de lo que sí se pudo convertir.
  final int cents;

  /// Las monedas con saldo que no se sumaron por no tener tasa.
  final Set<String> missing;

  bool get isComplete => missing.isEmpty;
}
