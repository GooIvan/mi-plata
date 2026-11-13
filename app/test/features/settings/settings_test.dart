import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_app.dart';

Future<void> openSettings(WidgetTester tester) async {
  // La pantalla creció con la apariencia: una vista alta deja todo en el árbol.
  tallView(tester);
  await openFromMore(tester, 'Ajustes');
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
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    expect(find.text("You don't have any accounts yet"), findsOneWidget);
    expect(find.text('Aún no tienes cuentas'), findsNothing);
  });

  testWidgets('volver a español', (tester) async {
    await pumpMiPlata(tester, language: 'en');
    await openFromMore(tester, 'Settings', more: 'More');

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

  group('apariencia', () {
    Finder themeOption(String label) =>
        find.widgetWithText(RadioListTile<ThemeMode>, label);

    Future<String?> savedTheme() async =>
        (await SharedPreferences.getInstance()).getString('themeMode');

    Brightness shown(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    void phoneIs(WidgetTester tester, Brightness brightness) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }

    testWidgets('por defecto sigue al teléfono, claro u oscuro', (
      tester,
    ) async {
      phoneIs(tester, Brightness.dark);
      await pumpMiPlata(tester);
      expect(shown(tester), Brightness.dark);

      phoneIs(tester, Brightness.light);
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.light);
    });

    testWidgets('el selector tiene tres opciones y marca "Tema del teléfono"', (
      tester,
    ) async {
      await pumpMiPlata(tester);
      await openSettings(tester);

      expect(find.text('Apariencia'), findsOneWidget);
      for (final label in ['Tema del teléfono', 'Claro', 'Oscuro']) {
        expect(themeOption(label), findsOneWidget, reason: label);
      }
      expect(
        tester
            .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
            .groupValue,
        ThemeMode.system,
      );
    });

    testWidgets(
      'elegir Oscuro cambia la app al instante aunque el teléfono sea claro',
      (tester) async {
        phoneIs(tester, Brightness.light);
        await pumpMiPlata(tester);
        await openSettings(tester);
        expect(shown(tester), Brightness.light);

        await tester.tap(themeOption('Oscuro'));
        await tester.pumpAndSettle();

        expect(shown(tester), Brightness.dark);
        expect(await savedTheme(), 'dark');
      },
    );

    testWidgets('elegir Claro cambia la app aunque el teléfono sea oscuro', (
      tester,
    ) async {
      phoneIs(tester, Brightness.dark);
      await pumpMiPlata(tester);
      await openSettings(tester);

      await tester.tap(themeOption('Claro'));
      await tester.pumpAndSettle();

      expect(shown(tester), Brightness.light);
      expect(await savedTheme(), 'light');
    });

    testWidgets('la elección guardada se aplica al abrir la app', (
      tester,
    ) async {
      phoneIs(tester, Brightness.light);
      await pumpMiPlata(tester, themeMode: 'dark');
      expect(shown(tester), Brightness.dark);

      await openSettings(tester);
      expect(
        tester
            .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
            .groupValue,
        ThemeMode.dark,
      );
    });

    testWidgets('volver a "Tema del teléfono" borra la elección', (
      tester,
    ) async {
      phoneIs(tester, Brightness.light);
      await pumpMiPlata(tester, themeMode: 'dark');
      await openSettings(tester);

      await tester.tap(themeOption('Tema del teléfono'));
      await tester.pumpAndSettle();

      expect(shown(tester), Brightness.light);
      expect(await savedTheme(), isNull);
    });

    testWidgets('un valor guardado desconocido cae en "teléfono"', (
      tester,
    ) async {
      phoneIs(tester, Brightness.light);
      await pumpMiPlata(tester, themeMode: 'morado');
      expect(shown(tester), Brightness.light);
    });

    testWidgets('el selector sale en inglés con la app en inglés', (
      tester,
    ) async {
      await pumpMiPlata(tester, language: 'en');
      await openFromMore(tester, 'Settings', more: 'More');

      expect(find.text('Appearance'), findsOneWidget);
      for (final label in ['Phone theme', 'Light', 'Dark']) {
        expect(themeOption(label), findsOneWidget, reason: label);
      }
    });
  });

  testWidgets('cerrar sesión desde los ajustes', (tester) async {
    final auth = FakeAuthRepository(signedInAs: 'ana@correo.com');
    await pumpMiPlata(tester, auth: auth);
    await openSettings(tester);

    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
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
