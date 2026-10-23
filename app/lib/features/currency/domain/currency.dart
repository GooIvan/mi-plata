/// Una moneda que la app sabe mostrar.
class Currency {
  const Currency(this.code, this.symbol);

  /// El código ISO de tres letras ("COP").
  final String code;

  /// Lo que se escribe antes del monto. Distingue a las que comparten el signo
  /// de peso: "$" es el peso colombiano y "US$" el dólar.
  final String symbol;
}

/// Las monedas que se pueden elegir para una cuenta o como moneda base.
///
/// La base de datos acepta cualquier código de tres letras; esta lista es la
/// que ofrece la interfaz. Todas se guardan con dos decimales.
const supportedCurrencies = [
  Currency('COP', r'$'),
  Currency('USD', r'US$'),
  Currency('EUR', '€'),
  Currency('MXN', r'MX$'),
  Currency('ARS', r'AR$'),
  Currency('BRL', r'R$'),
  Currency('CLP', r'CL$'),
  Currency('PEN', 'S/'),
  Currency('GBP', '£'),
  Currency('CAD', r'CA$'),
];

/// La moneda en la que está todo mientras el usuario no elija otra.
const defaultCurrency = 'COP';

/// El símbolo de [code]; si no está en la lista, el código mismo.
String currencySymbol(String code) {
  for (final currency in supportedCurrencies) {
    if (currency.code == code) return currency.symbol;
  }
  return '$code ';
}
