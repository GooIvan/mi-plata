import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

FakeBackend _backend() {
  final backend = FakeBackend(
    accounts: [
      testAccount('Bancolombia', balance: 1000000),
      testAccount('Nequi', type: AccountType.wallet, balance: 50000),
    ],
  );
  backend.debts
    ..seedDebt(counterparty: 'Juan', amount: 500000)
    ..seedDebt(
      direction: DebtDirection.receivable,
      counterparty: 'María',
      amount: 300000,
    );
  return backend;
}

Future<FakeBackend> _openDebts(WidgetTester tester, String language) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = _backend();
  await pumpMiPlata(tester, backend: backend, language: language);
  await goTo(tester, AppRoutes.debts);
  return backend;
}

Finder _field(int index) => find.byType(TextFormField).at(index);
Finder _button(String label) => find.widgetWithText(FilledButton, label);

Future<void> _pickAccount(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// La descripción del movimiento más reciente de la cuenta.
String? _lastDescription(FakeBackend backend) =>
    backend.transactions.transactions.last.description;

void main() {
  setUpAll(initDates);

  // Estas descripciones quedan guardadas como datos del usuario: se escriben en
  // el idioma que tenía la app al crearlas, no en el de la base de datos.
  group('el movimiento de un préstamo', () {
    for (final (language, create, owe, expected) in [
      ('es', 'Nueva deuda', 'Crear deuda', 'Préstamo de Luis'),
      ('en', 'New debt', 'Create debt', 'Loan from Luis'),
    ]) {
      testWidgets('$language: recibido', (tester) async {
        final backend = await _openDebts(tester, language);

        await tester.tap(find.widgetWithText(FloatingActionButton, create));
        await tester.pumpAndSettle();
        await tester.enterText(_field(0), 'Luis');
        await tester.enterText(_field(1), language == 'es' ? '250.000' : '250,000');
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await _pickAccount(tester, 'Bancolombia');
        await tester.tap(_button(owe));
        await tester.pumpAndSettle();

        expect(_lastDescription(backend), expected);
      });
    }

    testWidgets('en: prestado dice "Loan to"', (tester) async {
      final backend = await _openDebts(tester, 'en');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owed to me').last); // el selector de sentido
      await tester.pumpAndSettle();
      await tester.enterText(_field(0), 'Luis');
      await tester.enterText(_field(1), '250,000');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await _pickAccount(tester, 'Bancolombia');
      await tester.tap(_button('Create debt'));
      await tester.pumpAndSettle();

      expect(_lastDescription(backend), 'Loan to Luis');
    });
  });

  group('el movimiento de un abono', () {
    Future<void> openPayment(WidgetTester tester, String language, String debtor) async {
      await tester.tap(find.text(debtor));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }

    testWidgets('en inglés, sin descripción, se llama "Payment to ..."', (tester) async {
      final backend = await _openDebts(tester, 'en');
      await openPayment(tester, 'en', 'Juan');

      await tester.enterText(_field(0), '100,000');
      await _pickAccount(tester, 'Bancolombia');
      await tester.tap(_button('Record payment').last);
      await tester.pumpAndSettle();

      expect(_lastDescription(backend), 'Payment to Juan');
    });

    testWidgets('en español, sin descripción, se llama "Abono a ..."', (tester) async {
      final backend = await _openDebts(tester, 'es');
      await openPayment(tester, 'es', 'Juan');

      await tester.enterText(_field(0), '100.000');
      await _pickAccount(tester, 'Bancolombia');
      await tester.tap(_button('Registrar abono').last);
      await tester.pumpAndSettle();

      expect(_lastDescription(backend), 'Abono a Juan');
    });

    testWidgets('una cobranza en inglés se llama "Payment from ..."', (tester) async {
      final backend = await _openDebts(tester, 'en');
      await tester.tap(find.widgetWithText(Tab, 'Owed to me'));
      await tester.pumpAndSettle();
      await openPayment(tester, 'en', 'María');

      await tester.enterText(_field(0), '100,000');
      await _pickAccount(tester, 'Nequi');
      await tester.tap(_button('Record payment').last);
      await tester.pumpAndSettle();

      expect(_lastDescription(backend), 'Payment from María');
    });

    testWidgets('lo que el usuario escribe se respeta', (tester) async {
      final backend = await _openDebts(tester, 'en');
      await openPayment(tester, 'en', 'Juan');

      await tester.enterText(_field(0), '100,000');
      await _pickAccount(tester, 'Bancolombia');
      await tester.enterText(_field(1), 'Cuota de octubre');
      await tester.tap(_button('Record payment').last);
      await tester.pumpAndSettle();

      expect(_lastDescription(backend), 'Cuota de octubre');
    });
  });

  group('errores de la base de datos', () {
    testWidgets('la regla de la base se explica en inglés', (tester) async {
      final backend = await _openDebts(tester, 'en');
      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      backend.debts.error = const PostgrestException(
        message: 'El abono supera lo que falta por pagar',
        code: '23514',
        details: 'payment_exceeds_remaining',
      );
      await tester.enterText(_field(0), '100,000');
      await _pickAccount(tester, 'Bancolombia');
      await tester.tap(_button('Record payment').last);
      await tester.pumpAndSettle();

      expect(find.text('The payment exceeds what is left to pay'), findsOneWidget);
      expect(find.text('El abono supera lo que falta por pagar'), findsNothing);
    });

    testWidgets('y en español sigue diciendo lo de siempre', (tester) async {
      final backend = await _openDebts(tester, 'es');
      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      backend.debts.error = const PostgrestException(
        message: 'El abono supera lo que falta por pagar',
        code: '23514',
        details: 'payment_exceeds_remaining',
      );
      await tester.enterText(_field(0), '100.000');
      await _pickAccount(tester, 'Bancolombia');
      await tester.tap(_button('Registrar abono').last);
      await tester.pumpAndSettle();

      expect(find.text('El abono supera lo que falta por pagar'), findsOneWidget);
    });
  });
}
