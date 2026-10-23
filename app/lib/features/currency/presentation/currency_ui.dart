import '../../../l10n/l10n.dart';

/// El nombre de la moneda [code] en el idioma de la app; si no está en la
/// lista, el código mismo.
String currencyName(AppLocalizations l10n, String code) => switch (code) {
  'COP' => l10n.currencyNameCop,
  'USD' => l10n.currencyNameUsd,
  'EUR' => l10n.currencyNameEur,
  'MXN' => l10n.currencyNameMxn,
  'ARS' => l10n.currencyNameArs,
  'BRL' => l10n.currencyNameBrl,
  'CLP' => l10n.currencyNameClp,
  'PEN' => l10n.currencyNamePen,
  'GBP' => l10n.currencyNameGbp,
  'CAD' => l10n.currencyNameCad,
  _ => code,
};

/// "USD · Dólar estadounidense": para listas y selectores.
String currencyOptionLabel(AppLocalizations l10n, String code) =>
    l10n.currencyOption(code, currencyName(l10n, code));
