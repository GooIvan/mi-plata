import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_plata/app.dart';
import 'package:mi_plata/core/format/formats.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/core/riverpod/no_retry.dart';
import 'package:mi_plata/core/storage/preferences_provider.dart';
import 'package:mi_plata/features/currency/domain/currency_converter.dart';
import 'package:mi_plata/features/accounts/presentation/accounts_providers.dart';
import 'package:mi_plata/features/accounts/presentation/card_providers.dart';
import 'package:mi_plata/features/currency/presentation/rates_refresh.dart';
import 'package:mi_plata/features/profile/presentation/profile_providers.dart';
import 'package:mi_plata/features/auth/presentation/auth_providers.dart';
import 'package:mi_plata/features/budgets/presentation/budgets_providers.dart';
import 'package:mi_plata/features/categories/presentation/categories_providers.dart';
import 'package:mi_plata/features/currency/presentation/currency_providers.dart';
import 'package:mi_plata/features/debts/presentation/debts_providers.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_providers.dart';
import 'package:mi_plata/features/savings/presentation/goals_providers.dart';
import 'package:mi_plata/features/summary/presentation/summary_providers.dart';
import 'package:mi_plata/features/transactions/presentation/transactions_providers.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_account_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_backend.dart';

/// Un texto con los espacios no separables normalizados (intl los usa).
Finder textLike(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data?.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ') ==
          text,
);

/// Prepara los datos de fecha de los idiomas de la app; se llama desde
/// `setUpAll`.
Future<void> initDates() async {
  for (final locale in dateLocales) {
    await initializeDateFormatting(locale);
  }
}

/// Los textos de la app en [language] ("es" o "en"), para pruebas que no
/// dibujan pantallas.
Future<AppLocalizations> loadL10n([String language = 'es']) =>
    AppLocalizations.delegate.load(Locale(language));

/// Montos y fechas en [language], para pruebas que no dibujan pantallas.
Future<Formats> loadFormats([String language = 'es']) async =>
    Formats(await loadL10n(language));

/// Un conversor sin tasas, con el peso colombiano como base: así se sumaba todo
/// antes de que hubiera varias monedas.
const copConverter = CurrencyConverter(base: 'COP');

/// Carga las fuentes reales de Flutter (Roboto y los íconos).
///
/// En las pruebas el texto sale con una fuente cuadrada y muy ancha, que
/// desborda donde la real no: sirve para probar que algo cabe de verdad en un
/// teléfono. Devuelve false si el SDK no trae las fuentes.
Future<bool> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final directory = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!directory.existsSync()) return false;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('${directory.path}/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);

  // La tipografía de la app, tal como se empaqueta en pubspec.yaml.
  final app = FontLoader('PlusJakartaSans');
  for (final file in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ]) {
    final bytes = File('assets/fonts/PlusJakartaSans-$file.ttf').readAsBytesSync();
    app.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await app.load();
  return true;
}

/// Una pantalla alta (900 × 3600): las listas se construyen bajo demanda y así
/// todo lo que tengan abajo también está en el árbol.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Una `MaterialApp` con los textos de la app, para probar widgets sueltos.
Widget localizedApp({required Widget home, String language = 'es'}) {
  return MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

/// Abre la app completa con repositorios falsos y espera a que se asiente.
///
/// Si no se indica otra cosa, hay una sesión iniciada, ninguna cuenta y la app
/// está en español (el idioma de la prueba no depende del equipo).
Future<FakeBackend> pumpMiPlata(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeBackend? backend,
  FakeAccountRepository? accountRepository,
  String? language = 'es',
  String? themeMode,
  FakeExchangeRateApi? rateApi,
  bool automaticRates = false,
  Map<String, Object> preferences = const {},
}) async {
  final fakes = backend ?? FakeBackend();
  SharedPreferences.setMockInitialValues({
    'language': ?language,
    'themeMode': ?themeMode,
    ...preferences,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository(signedInAs: 'ana@correo.com'),
        ),
        accountRepositoryProvider.overrideWithValue(
          accountRepository ?? fakes.accounts,
        ),
        transactionRepositoryProvider.overrideWithValue(fakes.transactions),
        categoryRepositoryProvider.overrideWithValue(fakes.categories),
        summaryRepositoryProvider.overrideWithValue(fakes.summary),
        debtRepositoryProvider.overrideWithValue(fakes.debts),
        budgetRepositoryProvider.overrideWithValue(fakes.budgets),
        currencyRepositoryProvider.overrideWithValue(fakes.currency),
        recurringRepositoryProvider.overrideWithValue(fakes.recurring),
        savingsGoalRepositoryProvider.overrideWithValue(fakes.goals),
        cardInstallmentRepositoryProvider.overrideWithValue(fakes.installments),
        profileRepositoryProvider.overrideWithValue(fakes.profile),
        // Sin salir a internet: un servicio de mentira, y sin actualizar al abrir
        // salvo que la prueba lo pida.
        exchangeRateApiProvider.overrideWithValue(rateApi ?? FakeExchangeRateApi()),
        automaticRatesOnOpenProvider.overrideWithValue(automaticRates),
      ],
      child: const MiPlataApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fakes;
}

/// Navega a [location] como lo haría un enlace, sin pasar por los botones. Las
/// pestañas de la barra se abren con `go`, como en la app; el resto, encima.
Future<void> goTo(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  const tabs = {
    AppRoutes.dashboard,
    AppRoutes.transactions,
    AppRoutes.accounts,
    AppRoutes.goals,
    AppRoutes.more,
  };
  final router = GoRouter.of(context);
  tabs.contains(location) ? router.go(location) : router.push(location);
  await tester.pumpAndSettle();
}

/// Abre una pantalla desde la pestaña "Más", como lo haría una persona.
Future<void> openFromMore(
  WidgetTester tester,
  String entry, {
  String more = 'Más',
}) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(more)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, entry));
  await tester.pumpAndSettle();
}

/// Toca un movimiento y, en su detalle, "Editar": abre el formulario de edición.
/// (Tocar un movimiento ya no abre la edición de golpe: primero se ve.)
Future<void> openMovementForEdit(WidgetTester tester, Finder movement) async {
  await tester.tap(movement);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
  await tester.pumpAndSettle();
}
