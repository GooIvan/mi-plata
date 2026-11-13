import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/profile/domain/profile_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

ProfileData ana() => ProfileData(
  firstName: 'Ana María',
  lastName: 'Pérez Gómez',
  birthDate: DateTime(1990, 5, 17),
  profession: 'Diseñadora',
  monthlyIncome: '2500000',
  monthlyIncomeCurrency: 'COP',
);

// Campos de texto: 0 nombres, 1 apellidos, 2 profesión, 3 ingreso. El correo y
// la fecha no son campos de texto.
Finder field(int index) => find.byType(TextFormField).at(index);
Finder save() => find.widgetWithText(FilledButton, 'Guardar');

Future<({FakeBackend backend, FakeAuthRepository auth})> openProfile(
  WidgetTester tester, {
  ProfileData? profile,
  String language = 'es',
}) async {
  tallView(tester);
  final auth = FakeAuthRepository(signedInAs: 'ana@correo.com');
  final backend = FakeBackend(profile: profile);
  await pumpMiPlata(tester, auth: auth, backend: backend, language: language);
  await goTo(tester, AppRoutes.profile);
  return (backend: backend, auth: auth);
}

void main() {
  setUpAll(initDates);

  group('ver', () {
    testWidgets('muestra los datos guardados y el correo, que no se cambia', (
      tester,
    ) async {
      await openProfile(tester, profile: ana());

      expect(find.widgetWithText(TextFormField, 'Ana María'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pérez Gómez'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Diseñadora'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '2500000'), findsOneWidget);
      expect(find.text('17 de mayo de 1990'), findsOneWidget);
      expect(find.text('ana@correo.com'), findsOneWidget);
      expect(
        find.text('El correo no se puede cambiar desde aquí.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aún no tienes tus datos guardados'),
        findsNothing,
      );
    });

    testWidgets(
      'un usuario sin perfil lo ve vacío, con una nota, sin obligarlo a nada',
      (tester) async {
        final opened = await openProfile(tester);

        expect(
          find.textContaining('Aún no tienes tus datos guardados'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(field(0)).controller!.text,
          isEmpty,
        );
        expect(opened.backend.profile.saved, isEmpty);
      },
    );

    testWidgets('si no carga, lo dice y deja reintentar', (tester) async {
      tallView(tester);
      final backend = FakeBackend()..profile.error = Exception('sin red');
      await pumpMiPlata(tester, backend: backend);
      await goTo(tester, AppRoutes.profile);

      expect(find.text('No se pudo cargar tu perfil.'), findsOneWidget);

      backend.profile.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar tu perfil.'), findsNothing);
    });
  });

  group('editar', () {
    testWidgets('guarda los cambios y avisa', (tester) async {
      final opened = await openProfile(tester, profile: ana());

      await tester.enterText(field(0), '  Ana Lucía ');
      await tester.enterText(field(2), 'Ingeniera');
      await tester.enterText(field(3), '3.200.000');
      await tester.tap(save());
      await tester.pumpAndSettle();

      final saved = opened.backend.profile.saved.single;
      expect(saved.firstName, 'Ana Lucía');
      expect(saved.lastName, 'Pérez Gómez');
      expect(saved.profession, 'Ingeniera');
      expect(saved.monthlyIncome, '3200000');
      expect(saved.monthlyIncomeCurrency, 'COP');
      expect(saved.birthDate, DateTime(1990, 5, 17));
      expect(find.text('Perfil guardado'), findsOneWidget);
    });

    testWidgets('un usuario sin perfil lo completa y se guarda', (
      tester,
    ) async {
      final opened = await openProfile(tester);

      await tester.enterText(field(0), 'Ana');
      await tester.enterText(field(1), 'Pérez');
      await tester.tap(save());
      await tester.pumpAndSettle();

      final saved = opened.backend.profile.saved.single;
      expect(saved.firstName, 'Ana');
      expect(saved.profession, isNull);
      expect(saved.monthlyIncome, isNull);
      expect(saved.monthlyIncomeCurrency, isNull);
    });

    testWidgets('vaciar el ingreso o la profesión los quita', (tester) async {
      final opened = await openProfile(tester, profile: ana());

      await tester.enterText(field(2), '');
      await tester.enterText(field(3), '');
      await tester.tap(save());
      await tester.pumpAndSettle();

      final saved = opened.backend.profile.saved.single;
      expect(saved.profession, isNull);
      expect(saved.monthlyIncome, isNull);
      expect(saved.monthlyIncomeCurrency, isNull);
    });

    testWidgets('la fecha se puede quitar', (tester) async {
      final opened = await openProfile(tester, profile: ana());

      await tester.tap(find.byTooltip('Quitar la fecha'));
      await tester.pumpAndSettle();
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(opened.backend.profile.saved.single.birthDate, isNull);
    });

    testWidgets('mantiene la moneda del ingreso que ya tenía', (tester) async {
      final opened = await openProfile(
        tester,
        profile: const ProfileData(
          firstName: 'Ana',
          lastName: 'Pérez',
          monthlyIncome: '1000',
          monthlyIncomeCurrency: 'USD',
        ),
      );

      await tester.enterText(field(3), '1.200');
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(opened.backend.profile.saved.single.monthlyIncomeCurrency, 'USD');
    });

    testWidgets('nombres y apellidos siguen siendo obligatorios', (
      tester,
    ) async {
      final opened = await openProfile(tester, profile: ana());

      await tester.enterText(field(0), '');
      await tester.enterText(field(1), '   ');
      await tester.tap(save());
      await tester.pump();

      expect(find.text('Escribe tus nombres'), findsOneWidget);
      expect(find.text('Escribe tus apellidos'), findsOneWidget);
      expect(opened.backend.profile.saved, isEmpty);
    });

    testWidgets('un ingreso que no vale no se guarda', (tester) async {
      final opened = await openProfile(tester, profile: ana());

      await tester.enterText(field(3), '0');
      await tester.tap(save());
      await tester.pump();

      expect(find.text('Escribe un monto mayor que cero'), findsOneWidget);
      expect(opened.backend.profile.saved, isEmpty);
    });

    testWidgets('si la base rechaza el dato, lo explica en su idioma', (
      tester,
    ) async {
      final opened = await openProfile(tester, profile: ana());
      opened.backend.profile.error = const PostgrestException(
        message: 'La fecha de nacimiento no puede ser futura',
        code: '23514',
        details: 'profile_birth_date_future',
      );

      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        find.text('La fecha de nacimiento no puede ser futura'),
        findsOneWidget,
      );
      expect(find.text('Perfil guardado'), findsNothing);
    });

    testWidgets('si falla por otra razón, da un mensaje general', (
      tester,
    ) async {
      final opened = await openProfile(tester, profile: ana());
      opened.backend.profile.error = Exception('boom');

      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo guardar tu perfil. Revisa los datos e inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
    });
  });

  group('desde Ajustes e Inicio', () {
    testWidgets('Ajustes muestra el nombre y lleva al perfil', (tester) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: FakeBackend(profile: ana()));
      await openFromMore(tester, 'Ajustes');

      expect(find.text('Ana María Pérez Gómez'), findsOneWidget);
      expect(find.text('ana@correo.com'), findsOneWidget);

      await tester.tap(find.text('Ana María Pérez Gómez'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Ana María'), findsOneWidget);
    });

    testWidgets('sin perfil, Ajustes invita a completarlo', (tester) async {
      tallView(tester);
      await pumpMiPlata(tester);
      await openFromMore(tester, 'Ajustes');

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text('Completa tus datos'), findsOneWidget);
    });

    testWidgets('la inicial de Inicio sale del nombre y no del correo', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          profile: const ProfileData(firstName: 'Beatriz', lastName: 'Gómez'),
        ),
      );

      final avatar = find.descendant(
        of: find.byTooltip('ana@correo.com'),
        matching: find.byType(CircleAvatar),
      );
      expect(
        find.descendant(of: avatar, matching: find.text('B')),
        findsOneWidget,
      );
    });

    testWidgets('sin perfil, la inicial sigue saliendo del correo', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester);
      expect(
        find.descendant(
          of: find.byTooltip('ana@correo.com'),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    });
  });

  group('cambiar la contraseña', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
    }

    Finder dialogField(int index) => find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        )
        .at(index);

    testWidgets('la cambia y avisa', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      await openDialog(tester);

      await tester.enterText(dialogField(0), 'nueva-clave-123');
      await tester.enterText(dialogField(1), 'nueva-clave-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
      await tester.pumpAndSettle();

      expect(opened.auth.updatedPasswords, ['nueva-clave-123']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
    });

    testWidgets('exige 8 caracteres y que coincidan', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      await openDialog(tester);

      await tester.enterText(dialogField(0), 'corta');
      await tester.enterText(dialogField(1), 'otra');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
      await tester.pump();

      expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(opened.auth.updatedPasswords, isEmpty);
    });

    testWidgets('si el servicio la rechaza, lo dice y deja el diálogo', (
      tester,
    ) async {
      final opened = await openProfile(tester, profile: ana());
      opened.auth.error = const AuthApiException(
        'weak',
        statusCode: '422',
        code: 'weak_password',
      );
      await openDialog(tester);

      await tester.enterText(dialogField(0), 'nueva-clave-123');
      await tester.enterText(dialogField(1), 'nueva-clave-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('La contraseña es muy débil. Usa una más larga o más variada.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar no cambia nada', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      await openDialog(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(opened.auth.updatedPasswords, isEmpty);
    });
  });

  group('eliminar la cuenta', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Eliminar mi cuenta y mis datos'));
      await tester.pumpAndSettle();
    }

    testWidgets('avisa que no se puede deshacer y pide la contraseña', (
      tester,
    ) async {
      await openProfile(tester, profile: ana());
      await openDialog(tester);

      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      expect(find.text('Tu contraseña'), findsOneWidget);
    });

    testWidgets('sin la contraseña no borra nada', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      await openDialog(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Eliminar para siempre'),
      );
      await tester.pump();

      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(opened.backend.profile.accountDeleted, isFalse);
    });

    testWidgets(
      'con la contraseña correcta borra la cuenta y cierra la sesión',
      (tester) async {
        final opened = await openProfile(tester, profile: ana());
        await openDialog(tester);

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          'clave1234',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Eliminar para siempre'),
        );
        await tester.pumpAndSettle();

        expect(opened.backend.profile.accountDeleted, isTrue);
        expect(
          opened.auth.calls,
          containsAllInOrder(['signIn:ana@correo.com', 'signOut']),
        );
        // Sin sesión, la app vuelve al inicio de sesión.
        expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      },
    );

    testWidgets('con la contraseña equivocada no borra nada', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      opened.auth.error = const AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      await openDialog(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'equivocada',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Eliminar para siempre'),
      );
      await tester.pumpAndSettle();

      expect(opened.backend.profile.accountDeleted, isFalse);
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('si la base falla al borrar, lo dice y no cierra la sesión', (
      tester,
    ) async {
      final opened = await openProfile(tester, profile: ana());
      opened.backend.profile.error = Exception('boom');
      await openDialog(tester);
      // El perfil ya estaba cargado: el error solo afecta a lo que sigue.

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'clave1234',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Eliminar para siempre'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo eliminar la cuenta. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(opened.auth.calls, isNot(contains('signOut')));
    });

    testWidgets('cancelar deja todo como estaba', (tester) async {
      final opened = await openProfile(tester, profile: ana());
      await openDialog(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(opened.backend.profile.accountDeleted, isFalse);
    });
  });

  testWidgets('todo sale en inglés con la app en inglés', (tester) async {
    await openProfile(tester, profile: ana(), language: 'en');

    expect(find.text('My profile'), findsOneWidget);
    expect(find.text("The email can't be changed from here."), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Delete my account and data'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
  });
}
