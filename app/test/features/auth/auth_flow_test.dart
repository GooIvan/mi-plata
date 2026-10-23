import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_app.dart';

Future<void> pumpApp(WidgetTester tester, FakeAuthRepository repository) =>
    pumpMiPlata(tester, auth: repository);

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);

Future<void> fillLogin(WidgetTester tester, String email, String password) async {
  await tester.enterText(field(0), email);
  await tester.enterText(field(1), password);
}

void main() {
  group('guardia de rutas', () {
    testWidgets('sin sesión muestra el inicio de sesión', (tester) async {
      await pumpApp(tester, FakeAuthRepository());

      expect(find.text('Inicia sesión para continuar'), findsOneWidget);
      expect(button('Entrar'), findsOneWidget);
    });

    testWidgets('con sesión muestra el panel con el correo', (tester) async {
      await pumpApp(tester, FakeAuthRepository(signedInAs: 'ana@correo.com'));

      expect(find.text('ana@correo.com'), findsOneWidget);
      expect(button('Entrar'), findsNothing);
    });

    testWidgets('cerrar sesión devuelve al inicio de sesión', (tester) async {
      final repository = FakeAuthRepository(signedInAs: 'ana@correo.com');
      await pumpApp(tester, repository);

      // Cerrar sesión vive en los ajustes.
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signOut']);
      expect(button('Entrar'), findsOneWidget);
    });
  });

  group('inicio de sesión', () {
    testWidgets('valida los campos y no llama al servidor', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);

      await tester.tap(button('Entrar'));
      await tester.pump();

      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('rechaza un correo con formato inválido', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);

      await fillLogin(tester, 'esto-no-es-un-correo', 'clave1234');
      await tester.tap(button('Entrar'));
      await tester.pump();

      expect(find.text('El correo no es válido'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('con credenciales correctas lleva al panel', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);

      await fillLogin(tester, '  ana@correo.com ', 'clave1234');
      await tester.tap(button('Entrar'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signIn:ana@correo.com']);
      expect(find.text('ana@correo.com'), findsOneWidget);
      expect(button('Entrar'), findsNothing);
    });

    testWidgets('con credenciales inválidas muestra el error en español', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..error = const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        );
      await pumpApp(tester, repository);

      await fillLogin(tester, 'ana@correo.com', 'mala-clave');
      await tester.tap(button('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(button('Entrar'), findsOneWidget);
    });

    testWidgets('sin conexión muestra el aviso', (tester) async {
      final repository = FakeAuthRepository()
        ..error = AuthRetryableFetchException();
      await pumpApp(tester, repository);

      await fillLogin(tester, 'ana@correo.com', 'clave1234');
      await tester.tap(button('Entrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No hay conexión'), findsOneWidget);
    });
  });

  group('registro', () {
    Future<void> openRegister(WidgetTester tester) async {
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
    }

    Future<void> fillRegister(
      WidgetTester tester, {
      String email = 'ana@correo.com',
      String password = 'clave1234',
      String confirmation = 'clave1234',
    }) async {
      await tester.enterText(field(0), email);
      await tester.enterText(field(1), password);
      await tester.enterText(field(2), confirmation);
    }

    testWidgets('se llega desde el inicio de sesión y se puede volver', (
      tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());

      await openRegister(tester);
      expect(button('Crear cuenta'), findsOneWidget);

      await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
      await tester.pumpAndSettle();
      expect(button('Entrar'), findsOneWidget);
    });

    testWidgets('exige contraseña de al menos 8 caracteres', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);
      await openRegister(tester);

      await fillRegister(tester, password: 'corta', confirmation: 'corta');
      await tester.tap(button('Crear cuenta'));
      await tester.pump();

      expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('detecta contraseñas que no coinciden', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);
      await openRegister(tester);

      await fillRegister(tester, confirmation: 'otra-clave-1234');
      await tester.tap(button('Crear cuenta'));
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('un registro correcto lleva al panel', (tester) async {
      final repository = FakeAuthRepository();
      await pumpApp(tester, repository);
      await openRegister(tester);

      await fillRegister(tester);
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signUp:ana@correo.com']);
      expect(find.text('ana@correo.com'), findsOneWidget);
    });

    testWidgets('si falta confirmar el correo vuelve al login con aviso', (
      tester,
    ) async {
      final repository = FakeAuthRepository()..confirmationRequired = true;
      await pumpApp(tester, repository);
      await openRegister(tester);

      await fillRegister(tester);
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(button('Entrar'), findsOneWidget);
      expect(find.textContaining('confirmar tu cuenta'), findsOneWidget);
    });

    testWidgets('con un correo ya registrado muestra el error', (tester) async {
      final repository = FakeAuthRepository()
        ..error = const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        );
      await pumpApp(tester, repository);
      await openRegister(tester);

      await fillRegister(tester);
      await tester.tap(button('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya existe una cuenta con ese correo.'),
        findsOneWidget,
      );
    });
  });
}
