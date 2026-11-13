import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_app.dart';

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);

// Campos: 0 correo, 1 contraseña, 2 repetir, 3 nombres, 4 apellidos,
// 5 profesión, 6 ingreso. La fecha de nacimiento no es un campo de texto.

Future<FakeAuthRepository> openRegister(
  WidgetTester tester, {
  String language = 'es',
}) async {
  tallView(tester);
  final repository = FakeAuthRepository();
  await pumpMiPlata(tester, auth: repository, language: language);
  await tester.tap(
    find.text(
      language == 'es'
          ? '¿No tienes cuenta? Regístrate'
          : "Don't have an account? Sign up",
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> fillCredentials(WidgetTester tester) async {
  await tester.enterText(field(0), 'ana@correo.com');
  await tester.enterText(field(1), 'clave1234');
  await tester.enterText(field(2), 'clave1234');
}

void main() {
  setUpAll(initDates);

  testWidgets('el registro explica para qué son los datos personales', (
    tester,
  ) async {
    await openRegister(tester);

    expect(find.text('Sobre ti'), findsOneWidget);
    expect(find.textContaining('solo tú los ves'), findsOneWidget);
    for (final label in [
      'Nombres',
      'Apellidos',
      'Fecha de nacimiento (opcional)',
      'Profesión u ocupación (opcional)',
      'Ingreso mensual (opcional)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('nombres y apellidos son obligatorios', (tester) async {
    final repository = await openRegister(tester);

    await fillCredentials(tester);
    await tester.tap(button('Crear cuenta'));
    await tester.pump();

    expect(find.text('Escribe tus nombres'), findsOneWidget);
    expect(find.text('Escribe tus apellidos'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('lo demás es opcional: solo con nombres se registra', (
    tester,
  ) async {
    final repository = await openRegister(tester);

    await fillCredentials(tester);
    await tester.enterText(field(3), '  Ana María ');
    await tester.enterText(field(4), 'Pérez Gómez');
    await tester.tap(button('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['signUp:ana@correo.com']);
    final profile = repository.signedUpWithProfile!;
    expect(profile.firstName, 'Ana María');
    expect(profile.lastName, 'Pérez Gómez');
    expect(profile.birthDate, isNull);
    expect(profile.profession, isNull);
    expect(profile.monthlyIncome, isNull);
    expect(profile.monthlyIncomeCurrency, isNull);
  });

  testWidgets('manda todos los datos que se dieron', (tester) async {
    final repository = await openRegister(tester);

    await fillCredentials(tester);
    await tester.enterText(field(3), 'Ana');
    await tester.enterText(field(4), 'Pérez');
    await tester.enterText(field(5), 'Diseñadora gráfica');
    await tester.enterText(field(6), '2.500.000');
    // Fecha de nacimiento con el selector.
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    await tester.tap(button('Crear cuenta'));
    await tester.pumpAndSettle();

    final profile = repository.signedUpWithProfile!;
    expect(profile.profession, 'Diseñadora gráfica');
    expect(profile.monthlyIncome, '2500000');
    expect(profile.monthlyIncomeCurrency, 'COP');
    expect(profile.birthDate!.day, 15);
    // Hace unos 30 años: el selector abre ahí.
    expect(profile.birthDate!.year, DateTime.now().year - 30);
  });

  testWidgets('la fecha elegida se ve y se puede quitar', (tester) async {
    final repository = await openRegister(tester);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining(' de '), findsWidgets);
    await tester.tap(find.byTooltip('Quitar la fecha'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quitar la fecha'), findsNothing);

    await fillCredentials(tester);
    await tester.enterText(field(3), 'Ana');
    await tester.enterText(field(4), 'Pérez');
    await tester.tap(button('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(repository.signedUpWithProfile!.birthDate, isNull);
  });

  testWidgets('un ingreso que no es un monto, o es cero, no se acepta', (
    tester,
  ) async {
    final repository = await openRegister(tester);

    await fillCredentials(tester);
    await tester.enterText(field(3), 'Ana');
    await tester.enterText(field(4), 'Pérez');
    await tester.enterText(field(6), 'mucho');
    await tester.tap(button('Crear cuenta'));
    await tester.pump();
    expect(find.textContaining('Monto no válido'), findsOneWidget);

    await tester.enterText(field(6), '0');
    await tester.tap(button('Crear cuenta'));
    await tester.pump();
    expect(find.text('Escribe un monto mayor que cero'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('los nombres demasiado largos se rechazan', (tester) async {
    final repository = await openRegister(tester);

    await fillCredentials(tester);
    await tester.enterText(field(3), 'x' * 61);
    await tester.enterText(field(4), 'Pérez');
    await tester.tap(button('Crear cuenta'));
    await tester.pump();

    expect(find.text('Usa 60 caracteres o menos'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('en inglés, todo el bloque sale en inglés', (tester) async {
    await openRegister(tester, language: 'en');

    expect(find.text('About you'), findsOneWidget);
    for (final label in [
      'First name',
      'Last name',
      'Date of birth (optional)',
      'Profession or occupation (optional)',
      'Monthly income (optional)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
