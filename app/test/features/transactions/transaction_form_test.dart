import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _today = DateTime.now();

FakeBackend twoAccounts() => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Nequi', type: AccountType.wallet, balance: 50000),
    testAccount('Vieja', balance: 1, archived: true),
  ],
  categories: [
    testCategory('Mercado', CategoryType.expense),
    testCategory('Transporte', CategoryType.expense),
    testCategory('Salario', CategoryType.income),
  ],
);

Finder newMovementButton() =>
    find.widgetWithText(FloatingActionButton, 'Nuevo movimiento');
Finder amountField() => find.byType(TextFormField).at(0);
Finder descriptionField() => find.byType(TextFormField).at(1);
Finder submit(String label) => find.widgetWithText(FilledButton, label);
/// Un segmento del selector de tipo (tocar el selector entero pulsaría el del medio).
Finder segment(String label) => find.descendant(
  of: find.byType(SegmentedButton<TransactionType>),
  matching: find.text(label),
);

/// Los desplegables de cuenta (Cuenta/Desde y Hacia), en orden de aparición.
Finder accountDropdown(int index) =>
    find.byType(DropdownButtonFormField<String>).at(index);
Finder categoryDropdown() => find.byType(DropdownButtonFormField<String?>);

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(newMovementButton());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initDates);

  group('registrar', () {
    testWidgets('un gasto con categoría y descripción', (tester) async {
      final backend = twoAccounts();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.enterText(amountField(), '120.000');
      await pick(tester, accountDropdown(0), 'Bancolombia');
      await pick(tester, categoryDropdown(), 'Mercado');
      await tester.enterText(descriptionField(), '  Compra semanal ');
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.created.single;
      expect(draft.type, TransactionType.expense);
      expect(draft.accountId, 'id-Bancolombia');
      expect(draft.destinationAccountId, isNull);
      expect(draft.categoryId, 'cat-Mercado');
      expect(draft.amount, '120000');
      expect(draft.description, 'Compra semanal');
      expect(DateUtils.isSameDay(draft.date, _today), isTrue);
      expect(find.text('Nuevo movimiento'), findsOneWidget); // volvió al panel (FAB)
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('un ingreso ofrece solo categorías de ingreso', (tester) async {
      final backend = twoAccounts();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.tap(segment('Ingreso'));
      await tester.pumpAndSettle();
      await tester.tap(categoryDropdown());
      await tester.pumpAndSettle();

      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
      await tester.tap(find.text('Salario'));
      await tester.pumpAndSettle();

      await tester.enterText(amountField(), '3.500.000,50');
      await pick(tester, accountDropdown(0), 'Nequi');
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.created.single;
      expect(draft.type, TransactionType.income);
      expect(draft.categoryId, 'cat-Salario');
      expect(draft.amount, '3500000.50');
    });

    testWidgets('al cambiar de tipo se borra la categoría elegida', (tester) async {
      await pumpMiPlata(tester, backend: twoAccounts());
      await openForm(tester);

      await pick(tester, categoryDropdown(), 'Mercado');
      expect(find.text('Mercado'), findsOneWidget);

      await tester.tap(segment('Ingreso'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsNothing);
      expect(find.text('Sin categoría'), findsOneWidget);
    });

    testWidgets('una transferencia pide origen y destino, sin categoría', (
      tester,
    ) async {
      final backend = twoAccounts();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.tap(segment('Transferencia'));
      await tester.pumpAndSettle();

      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hacia'), findsOneWidget);
      expect(categoryDropdown(), findsNothing);

      await tester.enterText(amountField(), '200000');
      await pick(tester, accountDropdown(0), 'Bancolombia');

      // El destino no ofrece la cuenta de origen ni las archivadas.
      await tester.tap(accountDropdown(1));
      await tester.pumpAndSettle();
      expect(find.text('Nequi'), findsOneWidget);
      expect(find.text('Vieja (archivada)'), findsNothing);
      await tester.tap(find.text('Nequi'));
      await tester.pumpAndSettle();

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.created.single;
      expect(draft.type, TransactionType.transfer);
      expect(draft.accountId, 'id-Bancolombia');
      expect(draft.destinationAccountId, 'id-Nequi');
      expect(draft.categoryId, isNull);

      // La transferencia no cambia el dinero total.
      expect(textLike(r'$1.050.000'), findsOneWidget);
    });

    testWidgets('con una sola cuenta la elige por ti', (tester) async {
      final backend = FakeBackend(accounts: [testAccount('Nequi', balance: 5000)]);
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.enterText(amountField(), '1000');
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(backend.transactions.created.single.accountId, 'id-Nequi');
    });

    testWidgets('sin cuentas pide crear una primero', (tester) async {
      await pumpMiPlata(tester);
      await openForm(tester);

      expect(
        find.text('Primero crea una cuenta para registrar movimientos.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);
    });
  });

  group('validaciones', () {
    testWidgets('exige monto y cuenta', (tester) async {
      final backend = twoAccounts();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.tap(submit('Registrar'));
      await tester.pump();

      expect(find.text('Ingresa el monto'), findsOneWidget);
      expect(find.text('Elige una cuenta'), findsOneWidget);
      expect(backend.transactions.created, isEmpty);
    });

    testWidgets('rechaza monto cero, negativo o mal escrito', (tester) async {
      await pumpMiPlata(tester, backend: twoAccounts());
      await openForm(tester);
      await pick(tester, accountDropdown(0), 'Bancolombia');

      for (final (input, message) in [
        ('0', 'El monto debe ser mayor que cero'),
        ('-5', 'El monto no puede ser negativo'),
        ('12.5', 'Monto no válido. Ejemplo: 1.500.000 o 1500,50'),
      ]) {
        await tester.enterText(amountField(), input);
        await tester.tap(submit('Registrar'));
        await tester.pump();
        expect(find.text(message), findsOneWidget, reason: 'monto "$input"');
      }
    });

    testWidgets('una transferencia necesita el destino', (tester) async {
      final backend = twoAccounts();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.tap(segment('Transferencia'));
      await tester.pumpAndSettle();
      await tester.enterText(amountField(), '1000');
      await pick(tester, accountDropdown(0), 'Bancolombia');
      await tester.tap(submit('Registrar'));
      await tester.pump();

      expect(find.text('Elige la cuenta de destino'), findsOneWidget);
      expect(backend.transactions.created, isEmpty);
    });

    testWidgets('no se puede transferir con una sola cuenta', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Nequi', balance: 5000)]),
      );
      await openForm(tester);

      await tester.tap(segment('Transferencia'));
      await tester.pumpAndSettle();
      await tester.enterText(amountField(), '1000');
      await tester.tap(submit('Registrar'));
      await tester.pump();

      expect(find.text('Necesitas otra cuenta para transferir'), findsOneWidget);
    });

    testWidgets('si el servidor falla avisa y deja el formulario abierto', (
      tester,
    ) async {
      final backend = twoAccounts();
      backend.transactions.error = const PostgrestException(
        message: 'boom',
        code: '500',
      );
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.enterText(amountField(), '1000');
      await pick(tester, accountDropdown(0), 'Bancolombia');
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo completar'), findsOneWidget);
      expect(submit('Registrar'), findsOneWidget);
    });
  });

  group('editar y eliminar', () {
    FakeBackend withOneExpense() => FakeBackend(
      accounts: [
        testAccount('Bancolombia', balance: 1000000),
        testAccount('Vieja', balance: 1, archived: true),
      ],
      categories: [testCategory('Mercado', CategoryType.expense)],
      transactions: [
        testTransaction(
          'tx-1',
          type: TransactionType.expense,
          accountId: 'id-Bancolombia',
          categoryId: 'cat-Mercado',
          amount: 120000,
          date: DateTime(_today.year, _today.month, _today.day),
          description: 'Compra semanal',
        ),
      ],
    );

    Future<void> openFirstMovement(WidgetTester tester) async {
      await goTo(tester, AppRoutes.transactions);
      await tester.tap(find.text('Compra semanal'));
      await tester.pumpAndSettle();
    }

    testWidgets('precarga los datos y guarda los cambios', (tester) async {
      final backend = withOneExpense();
      await pumpMiPlata(tester, backend: backend);
      await openFirstMovement(tester);

      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '120000'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Compra semanal'), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);

      await tester.enterText(amountField(), '95.500');
      await tester.tap(submit('Guardar cambios'));
      await tester.pumpAndSettle();

      final draft = backend.transactions.updated['tx-1']!;
      expect(draft.amount, '95500');
      expect(draft.categoryId, 'cat-Mercado');
      expect(textLike(r'-$95.500'), findsOneWidget);
    });

    testWidgets('pasar de gasto a transferencia limpia la categoría', (
      tester,
    ) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 1000000),
            testAccount('Nequi', balance: 0),
          ],
          categories: [testCategory('Mercado', CategoryType.expense)],
          transactions: [
            testTransaction(
              'tx-1',
              type: TransactionType.expense,
              accountId: 'id-Bancolombia',
              categoryId: 'cat-Mercado',
              amount: 1000,
              date: DateTime(_today.year, _today.month, _today.day),
              description: 'Prueba',
            ),
          ],
        ),
      );
      await goTo(tester, AppRoutes.transactions);
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      await tester.tap(segment('Transferencia'));
      await tester.pumpAndSettle();
      await pick(tester, accountDropdown(1), 'Nequi');
      await tester.tap(submit('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Bancolombia → Nequi'), findsOneWidget);
    });

    testWidgets('elimina tras confirmar y avisa', (tester) async {
      final backend = withOneExpense();
      await pumpMiPlata(tester, backend: backend);
      await openFirstMovement(tester);

      await tester.tap(find.byTooltip('Eliminar movimiento'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este movimiento?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(backend.transactions.deleted, ['tx-1']);
      expect(find.text('Movimiento eliminado'), findsOneWidget);
      expect(find.text('Compra semanal'), findsNothing);

      // De vuelta en el panel, el saldo ya no descuenta el movimiento borrado.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(textLike(r'$1.000.000'), findsNWidgets(2)); // el total y la cuenta
    });

    testWidgets('cancelar la confirmación no elimina nada', (tester) async {
      final backend = withOneExpense();
      await pumpMiPlata(tester, backend: backend);
      await openFirstMovement(tester);

      await tester.tap(find.byTooltip('Eliminar movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(backend.transactions.deleted, isEmpty);
      expect(find.text('Editar movimiento'), findsOneWidget);
    });
  });

  group('aviso de saldo negativo', () {
    FakeBackend nequiConCuatroMil({List<Transaction> transactions = const []}) =>
        FakeBackend(
          accounts: [
            testAccount('Nequi', type: AccountType.wallet, balance: 4000),
            testAccount('Efectivo', type: AccountType.cash, balance: 0),
            testAccount('Visa', type: AccountType.card, balance: -50000),
          ],
          transactions: transactions,
        );

    Future<void> fillExpense(
      WidgetTester tester, {
      required String amount,
      String account = 'Nequi',
    }) async {
      await openForm(tester);
      await tester.enterText(amountField(), amount);
      await pick(tester, accountDropdown(0), account);
    }

    testWidgets('un gasto mayor al saldo pide confirmar, y se puede corregir', (
      tester,
    ) async {
      final backend = nequiConCuatroMil();
      await pumpMiPlata(tester, backend: backend);
      await fillExpense(tester, amount: '6.000');

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Registrar de todos modos?'), findsOneWidget);
      expect(find.textContaining(r'Nequi quedará en -$2.000.'), findsOneWidget);
      expect(backend.transactions.created, isEmpty);

      // "Corregir" vuelve al formulario sin guardar nada.
      await tester.tap(find.widgetWithText(TextButton, 'Corregir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(submit('Registrar'), findsOneWidget);
      expect(backend.transactions.created, isEmpty);
    });

    testWidgets('"Registrar igual" guarda y el saldo queda en negativo', (
      tester,
    ) async {
      final backend = nequiConCuatroMil();
      await pumpMiPlata(tester, backend: backend);
      await fillExpense(tester, amount: '6.000');

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar igual'));
      await tester.pumpAndSettle();

      expect(backend.transactions.created, hasLength(1));
      expect(submit('Registrar'), findsNothing); // volvió al panel
      expect(textLike(r'-$2.000'), findsOneWidget);
    });

    testWidgets('dejar la cuenta justo en cero no avisa', (tester) async {
      final backend = nequiConCuatroMil();
      await pumpMiPlata(tester, backend: backend);
      await fillExpense(tester, amount: '4.000');

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.transactions.created, hasLength(1));
    });

    testWidgets('una transferencia avisa por la cuenta de origen', (tester) async {
      final backend = nequiConCuatroMil();
      await pumpMiPlata(tester, backend: backend);
      await openForm(tester);

      await tester.tap(segment('Transferencia'));
      await tester.pumpAndSettle();
      await tester.enterText(amountField(), '6000');
      await pick(tester, accountDropdown(0), 'Nequi');
      await pick(tester, accountDropdown(1), 'Efectivo');

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining(r'Nequi quedará en -$2.000.'), findsOneWidget);
      expect(find.textContaining('Efectivo quedará'), findsNothing);
      expect(backend.transactions.created, isEmpty);
    });

    testWidgets('en una tarjeta de crédito no avisa', (tester) async {
      final backend = nequiConCuatroMil();
      await pumpMiPlata(tester, backend: backend);
      await fillExpense(tester, amount: '20.000', account: 'Visa');

      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.transactions.created, hasLength(1));
    });

    group('al editar', () {
      // Nequi tenía 4.000, se gastaron 3.000 y hoy tiene 1.000.
      FakeBackend conUnGasto() => nequiConCuatroMil(
        transactions: [
          testTransaction(
            'tx-1',
            type: TransactionType.expense,
            accountId: 'id-Nequi',
            amount: 3000,
            date: DateTime(_today.year, _today.month, _today.day),
            description: 'Compra',
          ),
        ],
      );

      Future<void> openPurchase(WidgetTester tester) async {
        await goTo(tester, AppRoutes.transactions);
        await tester.tap(find.text('Compra'));
        await tester.pumpAndSettle();
      }

      testWidgets('subir el monto más allá del saldo avisa con "Guardar igual"', (
        tester,
      ) async {
        final backend = conUnGasto();
        await pumpMiPlata(tester, backend: backend);
        await openPurchase(tester);

        await tester.enterText(amountField(), '4.500');
        await tester.tap(submit('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(find.text('¿Guardar de todos modos?'), findsOneWidget);
        expect(find.textContaining(r'Nequi quedará en -$500.'), findsOneWidget);
        expect(backend.transactions.updated, isEmpty);

        await tester.tap(find.widgetWithText(FilledButton, 'Guardar igual'));
        await tester.pumpAndSettle();
        expect(backend.transactions.updated['tx-1']!.amount, '4500');
      });

      testWidgets('un cambio que sigue dentro del saldo no avisa', (tester) async {
        final backend = conUnGasto();
        await pumpMiPlata(tester, backend: backend);
        await openPurchase(tester);

        await tester.enterText(amountField(), '3.500'); // quedan 500
        await tester.tap(submit('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(backend.transactions.updated['tx-1']!.amount, '3500');
      });

      testWidgets('cambiar solo la descripción no avisa', (tester) async {
        final backend = conUnGasto();
        await pumpMiPlata(tester, backend: backend);
        await openPurchase(tester);

        await tester.enterText(descriptionField(), 'Compra del mes');
        await tester.tap(submit('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(backend.transactions.updated['tx-1']!.description, 'Compra del mes');
      });
    });

    testWidgets('eliminar un ingreso que ya se gastó lo advierte', (tester) async {
      // Entraron 5.000 y salieron 4.000: hoy hay 1.000. Borrar el ingreso deja -4.000.
      final backend = FakeBackend(
        accounts: [testAccount('Nequi', type: AccountType.wallet, balance: 0)],
        transactions: [
          testTransaction(
            'tx-in',
            type: TransactionType.income,
            accountId: 'id-Nequi',
            amount: 5000,
            date: DateTime(_today.year, _today.month, _today.day - 1),
            description: 'Sueldo',
          ),
          testTransaction(
            'tx-out',
            type: TransactionType.expense,
            accountId: 'id-Nequi',
            amount: 4000,
            date: DateTime(_today.year, _today.month, _today.day),
            description: 'Compra',
          ),
        ],
      );
      await pumpMiPlata(tester, backend: backend);
      await goTo(tester, AppRoutes.transactions);
      await tester.tap(find.text('Sueldo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Eliminar movimiento'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atención:'), findsOneWidget);
      expect(find.textContaining(r'Nequi quedará en -$4.000.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(backend.transactions.deleted, ['tx-in']);
    });

    testWidgets('eliminar un gasto no muestra ninguna advertencia', (tester) async {
      final backend = nequiConCuatroMil(
        transactions: [
          testTransaction(
            'tx-1',
            type: TransactionType.expense,
            accountId: 'id-Nequi',
            amount: 3000,
            date: DateTime(_today.year, _today.month, _today.day),
            description: 'Compra',
          ),
        ],
      );
      await pumpMiPlata(tester, backend: backend);
      await goTo(tester, AppRoutes.transactions);
      await tester.tap(find.text('Compra'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Eliminar movimiento'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atención:'), findsNothing);
    });
  });
}
