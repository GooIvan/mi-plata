import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/widgets/brand_mark.dart';

import '../support/fake_auth_repository.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(initDates);

  group('el nombre', () {
    test('es "Mi Plata": dos palabras, sin guion', () {
      expect(BrandMark.appName, 'Mi Plata');
    });

    testWidgets('es el título de la app', (tester) async {
      await pumpMiPlata(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'Mi Plata');
    });

    test('es el nombre que se ve bajo el ícono en Android', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:label="Mi Plata"'));
      expect(manifest, isNot(contains('android:label="mi_plata"')));
    });
  });

  group('la marca dentro de la app', () {
    testWidgets('la pantalla de acceso muestra el símbolo y "Mi Plata"', (
      tester,
    ) async {
      await pumpMiPlata(tester, auth: FakeAuthRepository());

      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.text('Mi Plata'), findsOneWidget);
      expect(find.text('mi-plata'), findsNothing);
    });

    testWidgets('la cabecera de Inicio muestra el símbolo y "Mi Plata"', (
      tester,
    ) async {
      await pumpMiPlata(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(BrandMark),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Mi Plata'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el símbolo carga la imagen de la marca sin errores', (
      tester,
    ) async {
      await pumpMiPlata(tester);

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(BrandMark),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as AssetImage).assetName, BrandMark.asset);
      expect(tester.takeException(), isNull);
    });
  });

  group('los archivos de la marca', () {
    test('la imagen que usa la app existe y está declarada en el pubspec', () {
      expect(File(BrandMark.asset).existsSync(), isTrue);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains(BrandMark.asset),
      );
    });

    test(
      'solo se empaqueta ese símbolo: el resto de assets/branding son fuentes',
      () {
        final lines = File('pubspec.yaml')
            .readAsLinesSync()
            .where((line) => line.trim().startsWith('- assets/branding'))
            .map((line) => line.trim().substring(2))
            .toList();
        expect(lines, [BrandMark.asset]);
      },
    );

    test('las piezas del ícono de Android están generadas', () {
      for (final file in [
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_monochrome.png',
      ]) {
        expect(File(file).existsSync(), isTrue, reason: file);
      }
      // El fondo del ícono es el azul noche del logo.
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('#050D1E'),
      );
    });

    test('el ícono incluye la versión de un solo color para Android 13', () {
      expect(
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
            .readAsStringSync(),
        contains('<monochrome>'),
      );
    });
  });
}
