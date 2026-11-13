import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/storage/preferences_provider.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../debts/presentation/debts_providers.dart';
import '../data/exchange_rate_api.dart';
import '../domain/automatic_rates.dart';
import 'currency_providers.dart';

/// El servicio de tasas de cambio. Las pruebas ponen uno falso.
final exchangeRateApiProvider = Provider<ExchangeRateApi>((ref) {
  final api = ExchangeRateApi();
  ref.onDispose(api.close);
  return api;
});

/// Si la app actualiza las tasas sola al abrirse. Está apagado por defecto: lo
/// enciende `main`, y así las pruebas no salen a internet ni cambian de datos.
final automaticRatesOnOpenProvider = Provider<bool>((ref) => false);

/// Qué pasó al pedir las tasas.
enum RatesRefresh {
  /// Se trajeron y se guardaron.
  updated,

  /// Ya se actualizaron hoy (solo cuando no se pidió a la fuerza).
  notNeeded,

  /// No hay monedas con tasa automática que actualizar.
  nothingToUpdate,

  /// El servicio o la base de datos fallaron: se quedan las últimas tasas.
  failed,
}

const _refreshedOnKey = 'ratesRefreshedOn';

/// Trae las tasas de hoy del servicio y las guarda como automáticas.
///
/// Se actualizan las monedas que el usuario usa (en cuentas o deudas) y las que
/// ya tienen una tasa automática. Las de tasa manual no se tocan, y la moneda
/// base no necesita tasa. Sin [force], se hace una sola vez al día: el servicio
/// también se actualiza una vez al día. Si algo falla, no se pierde nada: quedan
/// las últimas tasas guardadas.
Future<RatesRefresh> refreshAutomaticRates(
  WidgetRef ref, {
  bool force = false,
}) async {
  final preferences = ref.read(sharedPreferencesProvider);
  final today = toDbDate(DateTime.now());
  if (!force && preferences.getString(_refreshedOnKey) == today) {
    return RatesRefresh.notNeeded;
  }

  try {
    final converter = await ref.read(currencyConverterProvider.future);
    final accounts = await ref.read(accountsProvider.future);
    final debts = await ref.read(debtsProvider.future);

    final wanted = <String>{
      for (final account in accounts)
        if (!account.isArchived) account.currency,
      for (final debt in debts)
        if (!debt.isArchived) debt.currency,
      for (final rate in converter.rates.values)
        if (!rate.isManual) rate.currency,
    }..remove(converter.base);
    wanted.removeWhere((code) => converter.rates[code]?.isManual ?? false);
    if (wanted.isEmpty) return RatesRefresh.nothingToUpdate;

    final api = await ref.read(exchangeRateApiProvider).fetch();
    final rates = AutomaticRates.compute(
      base: converter.base,
      currencies: wanted,
      perUsd: api.perUsd,
    );
    if (rates.isEmpty) return RatesRefresh.failed;

    await ref.read(currencyRepositoryProvider).setAutomaticRates(rates);
    await preferences.setString(_refreshedOnKey, today);
    ref.invalidate(currencyConverterProvider);
    return RatesRefresh.updated;
  } on Object {
    return RatesRefresh.failed;
  }
}
