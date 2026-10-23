import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_app.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
}

Finder languageOption(String label) => find.widgetWithText(RadioListTile<String>, label);

/// El idioma que quedó guardado en el teléfono.
Future<String?> savedLanguage() async =>
    (await SharedPreferences.getInstance()).getString('language');

void main() {
  setUpAll(initDates);

  testWidgets('el panel lleva a los ajustes', (tester) async {
    await pumpMiPlata(tester);
    await openSettings(tester);

    expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Sesión iniciada como ana@correo.com'), findsOneWidget);
  });

  testWidgets('muestra el idioma elegido', (tester) async {
    await pumpMiPlata(tester);
    await openSettings(tester);

    final selected = tester.widget<RadioListTile<String>>(languageOption('Español'));
    expect(selected.value, 'es');
    expect(
      tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue,
      'es',
    );
  });

  testWidgets('cambiar a inglés traduce la app al instante y lo recuerda', (
    tester,
  ) async {
    await pumpMiPlata(tester);
    await openSettings(tester);

    await tester.tap(languageOption('English'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Signed in as ana@correo.com'), findsOneWidget);
    expect(await savedLanguage(), 'en');

    // Y las demás pantallas también.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text("You don't have any accounts yet"), findsOneWidget);
    expect(find.text('Aún no tienes cuentas'), findsNothing);
  });

  testWidgets('volver a español', (tester) async {
    await pumpMiPlata(tester, language: 'en');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(languageOption('Español'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
    expect(await savedLanguage(), 'es');
  });

  group('idioma del teléfono', () {
    testWidgets('sin elección sigue al teléfono: inglés', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpMiPlata(tester, language: null);

      expect(find.text("You don't have any accounts yet"), findsOneWidget);
    });

    testWidgets('sin elección sigue al teléfono: español', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'CO')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpMiPlata(tester, language: null);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
    });

    testWidgets('un idioma que la app no tiene cae en español', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpMiPlata(tester, language: null);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
    });

    testWidgets('elegir "Idioma del teléfono" borra la elección', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpMiPlata(tester); // empieza fijo en español
      await openSettings(tester);

      await tester.tap(languageOption('Idioma del teléfono'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      expect(await savedLanguage(), isNull);
    });
  });

  testWidgets('cerrar sesión desde los ajustes', (tester) async {
    final auth = FakeAuthRepository(signedInAs: 'ana@correo.com');
    await pumpMiPlata(tester, auth: auth);
    await openSettings(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  });

  testWidgets('sin sesión la ruta de ajustes lleva al acceso', (tester) async {
    await pumpMiPlata(tester, auth: FakeAuthRepository());
    await goTo(tester, AppRoutes.settings);

    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  });
}
