import 'exchange_rate.dart';

/// Convierte dinero a la moneda base con las tasas que definió el usuario.
///
/// Una moneda sin tasa no se puede convertir: se devuelve null en vez de
/// inventar un valor, y quien suma decide qué decir (ver [missing]).
class CurrencyConverter {
  const CurrencyConverter({required this.base, this.rates = const {}});

  /// La moneda base ("COP"): lo que vale 1 de ella es 1.
  final String base;

  /// La tasa de cada moneda que no es la base.
  final Map<String, ExchangeRate> rates;

  bool canConvert(String currency) =>
      currency == base || rates.containsKey(currency);

  /// Cuánto vale 1 unidad de [currency] en la base, o null si no hay tasa.
  double? rateOf(String currency) =>
      currency == base ? 1 : rates[currency]?.rate;

  /// Pasa [cents] de [currency] a centavos de la base, redondeando al centavo.
  /// Null si la moneda no tiene tasa.
  int? toBaseCents(int cents, String currency) {
    if (currency == base) return cents;
    final rate = rates[currency]?.rate;
    if (rate == null) return null;
    return (cents * rate).round();
  }

  /// Las monedas de [currencies] que no se pueden convertir (sin repetir).
  Set<String> missing(Iterable<String> currencies) => {
    for (final currency in currencies)
      if (!canConvert(currency)) currency,
  };

  /// La tasa que dejan los dos montos de una transferencia entre monedas:
  /// cuántas unidades de la moneda de destino llegaron por cada una de la de
  /// origen. Null si alguno de los montos no es positivo.
  static double? impliedRate({
    required int fromCents,
    required int toCents,
  }) => fromCents <= 0 || toCents <= 0 ? null : toCents / fromCents;
}
