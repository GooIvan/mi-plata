import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../budgets/presentation/budgets_providers.dart';
import '../data/currency_repository.dart';
import '../domain/currency_converter.dart';

final currencyRepositoryProvider = Provider<CurrencyRepository>(
  (ref) => CurrencyRepository(ref.watch(supabaseClientProvider)),
);

/// La moneda base y las tasas de cambio, listas para convertir.
final currencyConverterProvider =
    AsyncNotifierProvider.autoDispose<CurrencyNotifier, CurrencyConverter>(
      CurrencyNotifier.new,
    );

/// Las operaciones lanzan el error si fallan, para que el formulario pueda
/// avisar al usuario.
class CurrencyNotifier extends AsyncNotifier<CurrencyConverter> {
  CurrencyRepository get _repository => ref.read(currencyRepositoryProvider);

  @override
  Future<CurrencyConverter> build() async {
    final (base, rates) = await (
      _repository.fetchBaseCurrency(),
      _repository.fetchRates(),
    ).wait;
    return CurrencyConverter(
      base: base,
      rates: {for (final rate in rates) rate.currency: rate},
    );
  }

  Future<void> setRate(String currency, String rate) async {
    await _repository.setRate(currency, rate);
    ref.invalidateSelf();
  }

  /// Hace automática la tasa de [currency]: la próxima actualización la
  /// reemplaza.
  Future<void> useAutomaticRate(String currency) async {
    await _repository.useAutomaticRate(currency);
    ref.invalidateSelf();
  }

  Future<void> deleteRate(String currency) async {
    await _repository.deleteRate(currency);
    ref.invalidateSelf();
  }

  /// Cambiar la base reexpresa las tasas y los presupuestos: se vuelven a leer
  /// los presupuestos y todo lo que se muestra convertido.
  Future<void> setBase(String currency, {String? rate}) async {
    await _repository.setBaseCurrency(currency, rate: rate);
    ref.invalidate(budgetRulesProvider);
    ref.read(ledgerRevisionProvider.notifier).bump();
    ref.invalidateSelf();
  }
}
