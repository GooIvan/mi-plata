import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/currency/data/exchange_rate_api.dart';
import 'package:mi_plata/features/currency/domain/automatic_rates.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

String today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

ExchangeRate manualRate(String currency, double rate) => ExchangeRate(
  currency: currency,
  rate: rate,
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  setUpAll(initDates);

  group('AutomaticRates.compute', () {
    // 1 dólar = 4.000 pesos, 0,9 euros y 20 pesos mexicanos.
    const perUsd = {'USD': 1.0, 'COP': 4000.0, 'EUR': 0.9, 'MXN': 20.0};

    test('con base COP: lo que vale 1 unidad de cada moneda en pesos', () {
      final rates = AutomaticRates.compute(
        base: 'COP',
        currencies: ['USD', 'EUR', 'MXN'],
        perUsd: perUsd,
      );

      expect(double.parse(rates['USD']!), closeTo(4000, 1e-6));
      expect(double.parse(rates['EUR']!), closeTo(4000 / 0.9, 1e-6));
      expect(double.parse(rates['MXN']!), closeTo(200, 1e-6));
    });

    test('con base USD, los pesos valen una fracción de dólar', () {
      final rates = AutomaticRates.compute(
        base: 'USD',
        currencies: ['COP'],
        perUsd: perUsd,
      );
      expect(double.parse(rates['COP']!), closeTo(0.00025, 1e-12));
    });

    test('la moneda base no lleva tasa', () {
      final rates = AutomaticRates.compute(
        base: 'COP',
        currencies: ['COP', 'USD'],
        perUsd: perUsd,
      );
      expect(rates.keys, ['USD']);
    });

    test(
      'una moneda que el servicio no trae se deja fuera, sin inventar nada',
      () {
        final rates = AutomaticRates.compute(
          base: 'COP',
          currencies: ['USD', 'XYZ'],
          perUsd: perUsd,
        );
        expect(rates.keys, ['USD']);
      },
    );

    test('si el servicio no trae la base, no se calcula nada', () {
      expect(
        AutomaticRates.compute(
          base: 'XYZ',
          currencies: ['USD'],
          perUsd: perUsd,
        ),
        isEmpty,
      );
    });

    test('valores en cero o negativos se ignoran', () {
      final rates = AutomaticRates.compute(
        base: 'COP',
        currencies: ['USD', 'EUR'],
        perUsd: const {'USD': 1.0, 'COP': 4000.0, 'EUR': 0.0},
      );
      expect(rates.keys, ['USD']);
    });

    test('la tasa cabe en 10 decimales, como decimal exacto en texto', () {
      final rates = AutomaticRates.compute(
        base: 'COP',
        currencies: ['EUR'],
        perUsd: perUsd,
      );
      expect(rates['EUR'], matches(RegExp(r'^\d+\.\d{10}$')));
    });
  });

  group('ExchangeRateApi', () {
    ExchangeRateApi apiReplying(http.Response Function(http.Request) reply) =>
        ExchangeRateApi(client: MockClient((request) async => reply(request)));

    String body({
      Object? rates,
      String result = 'success',
      Object? unix = 1794700000,
    }) => jsonEncode({
      'result': result,
      'time_last_update_unix': ?unix,
      'rates': rates ?? {'USD': 1, 'COP': 3288.648844, 'EUR': 0.8603},
    });

    test('lee las tasas y cuándo las actualizó el servicio', () async {
      final api = apiReplying((_) => http.Response(body(), 200));

      final rates = await api.fetch();

      expect(rates.perUsd['COP'], 3288.648844);
      expect(rates.perUsd['USD'], 1);
      expect(
        rates.updatedAt.toUtc(),
        DateTime.fromMillisecondsSinceEpoch(1794700000 * 1000, isUtc: true),
      );
    });

    test('pide las tasas respecto al dólar', () async {
      Uri? asked;
      final api = apiReplying((request) {
        asked = request.url;
        return http.Response(body(), 200);
      });
      await api.fetch();
      expect(asked.toString(), 'https://open.er-api.com/v6/latest/USD');
    });

    test('un estado de error falla con una excepción propia', () async {
      final api = apiReplying((_) => http.Response('no', 503));
      await expectLater(api.fetch(), throwsA(isA<ExchangeRateApiException>()));
    });

    test('un resultado que no es "success" falla', () async {
      final api = apiReplying((_) => http.Response(body(result: 'error'), 200));
      await expectLater(api.fetch(), throwsA(isA<ExchangeRateApiException>()));
    });

    test('una respuesta que no es JSON, o sin tasas, falla', () async {
      for (final text in [
        '<html>',
        '{}',
        '{"result":"success"}',
        '{"result":"success","rates":{"COP":"mucho"}}',
      ]) {
        final api = apiReplying((_) => http.Response(text, 200));
        await expectLater(
          api.fetch(),
          throwsA(isA<ExchangeRateApiException>()),
          reason: text,
        );
      }
    });

    test('sin internet falla con la misma excepción', () async {
      final api = ExchangeRateApi(
        client: MockClient((_) async => throw http.ClientException('sin red')),
      );
      await expectLater(api.fetch(), throwsA(isA<ExchangeRateApiException>()));
    });
  });

  group('al abrir la app', () {
    FakeBackend usingDollarsAndEuros({List<ExchangeRate> rates = const []}) =>
        FakeBackend(
          accounts: [
            testAccount('Banco', balance: 1000000),
            testAccount('Dólares', balance: 100, currency: 'USD'),
            testAccount('Euros', balance: 50, currency: 'EUR'),
          ],
          rates: rates,
        );

    testWidgets('trae las tasas de las monedas que usas, como automáticas', (
      tester,
    ) async {
      final api = FakeExchangeRateApi();
      final backend = await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(),
        rateApi: api,
        automaticRates: true,
      );

      expect(api.fetches, 1);
      expect(backend.currency.calls, contains('setAutomatic:EUR,USD'));
      expect(backend.currency.rates['USD']!.isManual, isFalse);
      expect(backend.currency.rates['USD']!.rate, closeTo(4000, 1e-6));
      expect(backend.currency.rates['EUR']!.rate, closeTo(4000 / 0.9, 1e-6));
      // Y el dinero total ya suma las otras monedas: 1.000.000 + 100 USD + 50 EUR.
      expect(textLike(r'$1.622.222,22'), findsOneWidget);
    });

    testWidgets('no pisa una tasa manual', (tester) async {
      final backend = await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(rates: [manualRate('USD', 4100)]),
        automaticRates: true,
      );

      expect(backend.currency.rates['USD']!.rate, 4100);
      expect(backend.currency.rates['USD']!.isManual, isTrue);
      // La del euro, que no tenía, sí se trae.
      expect(backend.currency.rates['EUR']!.isManual, isFalse);
    });

    testWidgets('actualiza una tasa que ya era automática', (tester) async {
      final backend = await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(
          rates: [
            ExchangeRate(
              currency: 'USD',
              rate: 3900,
              updatedAt: DateTime(2026, 10, 1),
              isManual: false,
            ),
          ],
        ),
        automaticRates: true,
      );

      expect(backend.currency.rates['USD']!.rate, closeTo(4000, 1e-6));
    });

    testWidgets('una sola vez al día', (tester) async {
      final api = FakeExchangeRateApi();
      await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(),
        rateApi: api,
        automaticRates: true,
        preferences: {'ratesRefreshedOn': today()},
      );

      expect(api.fetches, 0);
    });

    testWidgets(
      'si el servicio falla, quedan las últimas tasas y la app sigue',
      (tester) async {
        final api = FakeExchangeRateApi()
          ..error = const ExchangeRateApiException('caído');
        final backend = await pumpMiPlata(
          tester,
          backend: usingDollarsAndEuros(rates: [manualRate('USD', 4100)]),
          rateApi: api,
          automaticRates: true,
        );

        expect(api.fetches, 1);
        expect(backend.currency.rates['USD']!.rate, 4100);
        expect(backend.currency.rates.containsKey('EUR'), isFalse);
        expect(find.text('Dinero total'), findsOneWidget);
      },
    );

    testWidgets('si no se pudo, no marca el día: se vuelve a intentar después', (
      tester,
    ) async {
      final api = FakeExchangeRateApi()
        ..error = const ExchangeRateApiException('caído');
      await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(),
        rateApi: api,
        automaticRates: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ratesRefreshedOn'), isNull);
    });

    testWidgets('si se pudo, marca el día de hoy', (tester) async {
      await pumpMiPlata(
        tester,
        backend: usingDollarsAndEuros(),
        automaticRates: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ratesRefreshedOn'), today());
    });

    testWidgets('sin otras monedas no sale a internet', (tester) async {
      final api = FakeExchangeRateApi();
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Banco', balance: 1)]),
        rateApi: api,
        automaticRates: true,
      );
      expect(api.fetches, 0);
    });

    testWidgets('apagado (como en las pruebas), no actualiza nada', (
      tester,
    ) async {
      final api = FakeExchangeRateApi();
      await pumpMiPlata(tester, backend: usingDollarsAndEuros(), rateApi: api);
      expect(api.fetches, 0);
    });
  });

  group('pantalla de tasas', () {
    Finder refreshButton() => find.byTooltip('Actualizar tasas');

    FakeBackend backendWith(List<ExchangeRate> rates) => FakeBackend(
      accounts: [
        testAccount('Banco', balance: 1000000),
        testAccount('Dólares', balance: 100, currency: 'USD'),
        testAccount('Euros', balance: 50, currency: 'EUR'),
      ],
      rates: rates,
    );

    testWidgets('dice de dónde vienen las tasas y marca cada una', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: backendWith([
          manualRate('USD', 4100),
          ExchangeRate(
            currency: 'EUR',
            rate: 4400,
            updatedAt: DateTime.now(),
            isManual: false,
          ),
        ]),
      );
      await goTo(tester, AppRoutes.rates);

      expect(find.textContaining('ExchangeRate-API'), findsOneWidget);
      expect(find.textContaining('Manual'), findsOneWidget);
      expect(find.textContaining('Automática'), findsOneWidget);
    });

    testWidgets('actualizar trae las tasas y lo dice', (tester) async {
      tallView(tester);
      final api = FakeExchangeRateApi();
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith(const []),
        rateApi: api,
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      expect(find.text('Tasas actualizadas'), findsOneWidget);
      expect(api.fetches, 1);
      expect(backend.currency.rates.keys, containsAll(['USD', 'EUR']));
      expect(find.textContaining('Automática'), findsNWidgets(2));
    });

    testWidgets('actualizar a la fuerza funciona aunque ya se haya hecho hoy', (
      tester,
    ) async {
      tallView(tester);
      final api = FakeExchangeRateApi();
      await pumpMiPlata(
        tester,
        backend: backendWith(const []),
        rateApi: api,
        preferences: {'ratesRefreshedOn': today()},
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      expect(api.fetches, 1);
    });

    testWidgets('si falla, avisa y deja las tasas como estaban', (
      tester,
    ) async {
      tallView(tester);
      final api = FakeExchangeRateApi()
        ..error = const ExchangeRateApiException('caído');
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith([manualRate('USD', 4100)]),
        rateApi: api,
      );
      await goTo(tester, AppRoutes.rates);
      // Para que haya algo automático que actualizar.
      backend.currency.rates['EUR'] = ExchangeRate(
        currency: 'EUR',
        rate: 4400,
        updatedAt: DateTime(2026, 10, 1),
        isManual: false,
      );

      await tester.tap(refreshButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Se siguen usando las últimas tasas guardadas'),
        findsOneWidget,
      );
      expect(backend.currency.rates['EUR']!.rate, 4400);
    });

    testWidgets(
      'con todas las tasas manuales explica por qué no hay nada que actualizar',
      (tester) async {
        tallView(tester);
        final api = FakeExchangeRateApi();
        await pumpMiPlata(
          tester,
          backend: backendWith([
            manualRate('USD', 4100),
            manualRate('EUR', 4500),
          ]),
          rateApi: api,
        );
        await goTo(tester, AppRoutes.rates);

        await tester.tap(refreshButton());
        await tester.pumpAndSettle();

        expect(find.textContaining('tienen tasa manual'), findsOneWidget);
        expect(api.fetches, 0);
      },
    );

    testWidgets('al agregar una tasa, la opción automática aparece enseguida y la crea', (
      tester,
    ) async {
      tallView(tester);
      final api = FakeExchangeRateApi();
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith(const []),
        rateApi: api,
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Agregar tasa'));
      await tester.pumpAndSettle();
      // Sin elegir nada todavía, ya está la opción.
      expect(find.widgetWithText(TextButton, 'Usar la tasa automática'), findsOneWidget);

      // MXN no está en ninguna cuenta: se crea igual, a pedido.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('MXN').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Usar la tasa automática'));
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsNothing); // se cerró la hoja
      expect(backend.currency.rates['MXN']!.isManual, isFalse);
      expect(backend.currency.rates['MXN']!.rate, closeTo(200, 1e-6));
      expect(api.fetches, 1);
    });

    testWidgets('sin elegir moneda, la opción automática pide elegirla', (tester) async {
      tallView(tester);
      final api = FakeExchangeRateApi();
      await pumpMiPlata(tester, backend: backendWith(const []), rateApi: api);
      await goTo(tester, AppRoutes.rates);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Agregar tasa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Usar la tasa automática'));
      await tester.pumpAndSettle();

      expect(api.fetches, 0);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('si el servicio no responde al agregar, avisa y no crea nada', (
      tester,
    ) async {
      tallView(tester);
      final api = FakeExchangeRateApi()
        ..error = const ExchangeRateApiException('caído');
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith(const []),
        rateApi: api,
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Agregar tasa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('MXN').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Usar la tasa automática'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Se siguen usando las últimas tasas guardadas'),
        findsOneWidget,
      );
      expect(backend.currency.rates.containsKey('MXN'), isFalse);
      // La hoja sigue abierta para escribirla a mano.
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });

    testWidgets('una tasa manual se puede pasar a automática', (tester) async {
      tallView(tester);
      final api = FakeExchangeRateApi();
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith([
          manualRate('USD', 4100),
          manualRate('EUR', 4500),
        ]),
        rateApi: api,
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(find.textContaining('1 USD'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Usar la tasa automática'),
      );
      await tester.pumpAndSettle();

      expect(backend.currency.calls, contains('useAutomatic:USD'));
      expect(backend.currency.rates['USD']!.isManual, isFalse);
      expect(backend.currency.rates['USD']!.rate, closeTo(4000, 1e-6));
      // La otra sigue manual.
      expect(backend.currency.rates['EUR']!.isManual, isTrue);
      expect(backend.currency.rates['EUR']!.rate, 4500);
    });

    testWidgets(
      'en una tasa automática, el formulario avisa que se vuelve manual al cambiarla',
      (tester) async {
        tallView(tester);
        await pumpMiPlata(
          tester,
          backend: backendWith([
            ExchangeRate(
              currency: 'USD',
              rate: 4000,
              updatedAt: DateTime.now(),
              isManual: false,
            ),
          ]),
        );
        await goTo(tester, AppRoutes.rates);

        await tester.tap(find.textContaining('1 USD'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Esta tasa se actualiza sola. Si la cambias, pasa a manual.',
          ),
          findsOneWidget,
        );
        expect(find.text('Usar la tasa automática'), findsNothing);
      },
    );

    testWidgets('al editar una tasa automática a mano, queda manual', (
      tester,
    ) async {
      tallView(tester);
      final backend = await pumpMiPlata(
        tester,
        backend: backendWith([
          ExchangeRate(
            currency: 'USD',
            rate: 4000,
            updatedAt: DateTime.now(),
            isManual: false,
          ),
        ]),
      );
      await goTo(tester, AppRoutes.rates);

      await tester.tap(find.textContaining('1 USD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '4.250');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(backend.currency.rates['USD']!.isManual, isTrue);
      expect(backend.currency.rates['USD']!.rate, 4250);
    });

    testWidgets('todo sale en inglés con la app en inglés', (tester) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        language: 'en',
        backend: backendWith([manualRate('USD', 4100)]),
      );
      await goTo(tester, AppRoutes.rates);

      expect(find.byTooltip('Update rates'), findsOneWidget);
      expect(
        find.textContaining('Automatic rates come from ExchangeRate-API'),
        findsOneWidget,
      );
      expect(find.textContaining('Manual'), findsOneWidget);
    });
  });
}
