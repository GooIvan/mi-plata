/// Pasa las tasas de un servicio (cuántas unidades de cada moneda valen 1 dólar)
/// a las que usa la app (cuánto vale 1 unidad de cada moneda en la moneda base).
class AutomaticRates {
  const AutomaticRates._();

  /// Los decimales que caben en `numeric(20, 10)`.
  static const _decimals = 10;

  /// La tasa de cada moneda de [currencies] respecto a [base], lista para
  /// guardar como decimal exacto en texto.
  ///
  /// [perUsd] trae cuántas unidades de cada moneda valen 1 USD. Una moneda
  /// vale `perUsd[base] / perUsd[moneda]` unidades de la base. Las monedas que
  /// el servicio no trae (y la propia base) se dejan fuera: nunca se inventa un
  /// valor. Si la base no está en [perUsd], no se puede calcular nada.
  static Map<String, String> compute({
    required String base,
    required Iterable<String> currencies,
    required Map<String, double> perUsd,
  }) {
    final basePerUsd = perUsd[base];
    if (basePerUsd == null || basePerUsd <= 0) return const {};

    final result = <String, String>{};
    for (final currency in currencies) {
      if (currency == base) continue;
      final perUsdOfCurrency = perUsd[currency];
      if (perUsdOfCurrency == null || perUsdOfCurrency <= 0) continue;
      final rate = basePerUsd / perUsdOfCurrency;
      // Una tasa tan chica que se redondea a cero no sirve.
      if (double.parse(rate.toStringAsFixed(_decimals)) <= 0) continue;
      result[currency] = rate.toStringAsFixed(_decimals);
    }
    return result;
  }
}
