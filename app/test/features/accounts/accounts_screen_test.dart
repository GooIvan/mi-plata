import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/widgets/account_form_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/test_app.dart';

/// Abre la app con sesión iniciada y entra a la pantalla de cuentas.
Future<void> openAccounts(
  WidgetTester tester,
  FakeAccountRepository repository,
) async {
  await pumpMiPlata(tester, accountRepository: repository);
  await goTo(tester, AppRoutes.accounts);
}

Finder newAccountButton() =>
    find.widgetWithText(FloatingActionButton, 'Nueva cuenta');
Finder formField(int index) => find.byType(TextFormField).at(index);
Finder formButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  group('lista', () {
    testWidgets('sin cuentas muestra el estado vacío', (tester) async {
      await openAccounts(tester, FakeAccountRepository());

      expect(find.textContaining('Aún no tienes cuentas'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Crear cuenta'), findsOneWidget);
    });

    testWidgets('muestra cada cuenta con su tipo y su saldo', (tester) async {
      await openAccounts(
        tester,
        FakeAccountRepository([
          testAccount('Bancolombia', balance: 1500000),
          testAccount('Billetera', type: AccountType.cash, balance: 25000),
        ]),
      );

      expect(find.text('Bancolombia'), findsOneWidget);
      expect(find.text('Banco'), findsOneWidget);
      expect(textLike(r'$1.500.000'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(textLike(r'$25.000'), findsOneWidget);
    });

    testWidgets('un saldo negativo se muestra con signo menos', (tester) async {
      await openAccounts(
        tester,
        FakeAccountRepository([
          testAccount('Visa', type: AccountType.card, balance: -350000),
        ]),
      );

      expect(textLike(r'-$350.000'), findsOneWidget);
    });

    testWidgets('las archivadas se ocultan y se pueden mostrar', (tester) async {
      await openAccounts(
        tester,
        FakeAccountRepository([
          testAccount('Activa'),
          testAccount('Vieja', archived: true),
        ]),
      );

      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('Vieja'), findsNothing);

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();

      expect(find.text('Vieja'), findsOneWidget);
      expect(find.text('Banco · Archivada'), findsOneWidget);
    });

    testWidgets('si todas están archivadas lo avisa', (tester) async {
      await openAccounts(
        tester,
        FakeAccountRepository([testAccount('Vieja', archived: true)]),
      );

      expect(find.text('Todas tus cuentas están archivadas.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Mostrar archivadas'));
      await tester.pumpAndSettle();
      expect(find.text('Vieja'), findsOneWidget);
    });

    testWidgets('si falla la carga muestra el error y permite reintentar', (
      tester,
    ) async {
      final repository = FakeAccountRepository([testAccount('Bancolombia')])
        ..error = const PostgrestException(message: 'boom', code: '500');
      await openAccounts(tester, repository);

      expect(find.textContaining('No se pudo completar'), findsOneWidget);
      expect(find.text('Bancolombia'), findsNothing);

      repository.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Bancolombia'), findsOneWidget);
    });
  });

  group('crear', () {
    testWidgets('crea una cuenta y aparece en la lista', (tester) async {
      final repository = FakeAccountRepository();
      await openAccounts(tester, repository);

      await tester.tap(newAccountButton());
      await tester.pumpAndSettle();

      await tester.enterText(formField(0), '  Nequi ');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Billetera digital'));
      await tester.enterText(formField(1), '1.250.000,50');
      await tester.tap(formButton('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Nequi:wallet:1250000.50'));
      expect(find.byType(AccountFormSheet), findsNothing);
      expect(find.text('Nequi'), findsOneWidget);
      expect(textLike(r'$1.250.000,50'), findsOneWidget);
    });

    testWidgets('el saldo inicial vacío cuenta como cero', (tester) async {
      final repository = FakeAccountRepository();
      await openAccounts(tester, repository);

      await tester.tap(newAccountButton());
      await tester.pumpAndSettle();
      await tester.enterText(formField(0), 'Ahorros');
      await tester.tap(formButton('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Ahorros:bank:0'));
    });

    testWidgets('valida el nombre y el monto sin llamar al servidor', (
      tester,
    ) async {
      final repository = FakeAccountRepository();
      await openAccounts(tester, repository);

      await tester.tap(newAccountButton());
      await tester.pumpAndSettle();
      await tester.enterText(formField(1), '12.5');
      await tester.tap(formButton('Crear cuenta'));
      await tester.pump();

      expect(find.text('Ponle un nombre a la cuenta'), findsOneWidget);
      expect(find.textContaining('Monto no válido'), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('un nombre repetido muestra el error y deja el formulario', (
      tester,
    ) async {
      final repository = FakeAccountRepository([testAccount('Bancolombia')]);
      await openAccounts(tester, repository);

      await tester.tap(newAccountButton());
      await tester.pumpAndSettle();
      await tester.enterText(formField(0), 'bancolombia');
      await tester.tap(formButton('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya tienes una cuenta activa con ese nombre.'),
        findsOneWidget,
      );
      expect(find.byType(AccountFormSheet), findsOneWidget);
    });
  });

  group('editar y archivar', () {
    testWidgets('editar precarga los datos y guarda los cambios', (tester) async {
      final repository = FakeAccountRepository([
        testAccount('Bancolombia', balance: 1500000),
      ]);
      await openAccounts(tester, repository);

      await openAccountForEdit(tester, find.text('Bancolombia'));

      expect(find.text('Editar cuenta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Bancolombia'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1500000'), findsOneWidget);

      await tester.enterText(formField(0), 'Bancolombia nómina');
      await tester.tap(formButton('Guardar'));
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains('update:id-Bancolombia:Bancolombia nómina:bank:1500000'),
      );
      expect(find.text('Bancolombia nómina'), findsOneWidget);
    });

    testWidgets('archivar la saca de la lista y se puede deshacer', (
      tester,
    ) async {
      final repository = FakeAccountRepository([testAccount('Bancolombia')]);
      await openAccounts(tester, repository);

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta archivada'), findsOneWidget);
      expect(find.text('Todas tus cuentas están archivadas.'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(find.text('Bancolombia'), findsOneWidget);
      expect(repository.accounts.single.isArchived, isFalse);
    });

    testWidgets('restaurar una archivada la devuelve a la lista', (tester) async {
      final repository = FakeAccountRepository([
        testAccount('Vieja', archived: true),
      ]);
      await openAccounts(tester, repository);

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta restaurada'), findsOneWidget);
      expect(repository.accounts.single.isArchived, isFalse);
    });

    testWidgets('si falla al archivar avisa y no cambia nada', (tester) async {
      final repository = FakeAccountRepository([testAccount('Bancolombia')]);
      await openAccounts(tester, repository);

      repository.error = const PostgrestException(message: 'boom', code: '500');
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo completar'), findsOneWidget);
      expect(repository.accounts.single.isArchived, isFalse);
    });
  });
}
