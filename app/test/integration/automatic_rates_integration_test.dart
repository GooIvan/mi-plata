// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/currency/data/currency_repository.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(initDates);

  group(
    'Tasas automáticas contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      Future<CurrencyRepository> newUser(String prefix) async =>
          CurrencyRepository(await harness.signedUpClient(prefix));

      Future<ExchangeRate> rate(
        CurrencyRepository repo,
        String currency,
      ) async =>
          (await repo.fetchRates()).firstWhere((r) => r.currency == currency);

      test('crea las que faltan como automáticas', () async {
        final repo = await newUser('auto-crea');

        final written = await repo.setAutomaticRates({
          'USD': '4000.5000000000',
          'EUR': '4400.2500000000',
        });

        expect(written, 2);
        final usd = await rate(repo, 'USD');
        expect(usd.isManual, isFalse);
        expect(usd.rate, 4000.5);
        expect((await rate(repo, 'EUR')).rate, 4400.25);
      });

      test('actualiza las automáticas', () async {
        final repo = await newUser('auto-actualiza');
        await repo.setAutomaticRates({'USD': '4000'});

        final written = await repo.setAutomaticRates({'USD': '4100'});

        expect(written, 1);
        expect((await rate(repo, 'USD')).rate, 4100);
        expect((await rate(repo, 'USD')).isManual, isFalse);
      });

      test('nunca pisa una tasa manual', () async {
        final repo = await newUser('auto-manual');
        await repo.setRate('USD', '4250');

        final written = await repo.setAutomaticRates({
          'USD': '3999',
          'EUR': '4400',
        });

        // Solo se escribió la del euro.
        expect(written, 1);
        final usd = await rate(repo, 'USD');
        expect(usd.rate, 4250);
        expect(usd.isManual, isTrue);
        expect((await rate(repo, 'EUR')).isManual, isFalse);
      });

      test('lo que el usuario escribe a mano deja la tasa manual', () async {
        final repo = await newUser('auto-edita');
        await repo.setAutomaticRates({'USD': '4000'});

        await repo.setRate('USD', '4300');
        await repo.setAutomaticRates({'USD': '3900'});

        final usd = await rate(repo, 'USD');
        expect(usd.rate, 4300);
        expect(usd.isManual, isTrue);
      });

      test('una tasa manual se puede devolver a automática', () async {
        final repo = await newUser('auto-vuelve');
        await repo.setRate('USD', '4300');

        await repo.useAutomaticRate('USD');
        await repo.setAutomaticRates({'USD': '3900'});

        final usd = await rate(repo, 'USD');
        expect(usd.rate, 3900);
        expect(usd.isManual, isFalse);
      });

      test(
        'ignora la moneda base, los códigos raros y las tasas que no valen',
        () async {
          final repo = await newUser('auto-ignora');

          final written = await repo.setAutomaticRates({
            'COP': '1', // la base por defecto
            'usd': '4000', // minúsculas: se acepta como USD
            'XX': '5', // no son tres letras
            'EUR': '0', // no vale
          });

          expect(written, 1);
          final rates = await repo.fetchRates();
          expect(rates.map((r) => r.currency), ['USD']);
        },
      );

      test('si la base cambia, la nueva base no recibe tasa', () async {
        final repo = await newUser('auto-base');
        await repo.setBaseCurrency('USD');

        final written = await repo.setAutomaticRates({
          'USD': '1',
          'COP': '0.00025',
        });

        expect(written, 1);
        expect((await repo.fetchRates()).map((r) => r.currency), ['COP']);
      });

      test('cada usuario solo ve y cambia las suyas', () async {
        final ana = await newUser('auto-ana');
        final beto = await newUser('auto-beto');
        await ana.setAutomaticRates({'USD': '4000'});

        expect(await beto.fetchRates(), isEmpty);
        await beto.setAutomaticRates({'USD': '4500'});
        expect((await rate(ana, 'USD')).rate, 4000);
      });

      test('sin sesión no se puede', () async {
        final anonymous = CurrencyRepository(harness.newClient());
        await expectLater(
          anonymous.setAutomaticRates({'USD': '4000'}),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
