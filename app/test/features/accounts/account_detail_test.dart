import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/widgets/account_detail_sheet.dart';
import 'package:mi_plata/features/accounts/presentation/widgets/account_form_sheet.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime daysFromNow(int days) =>
    DateTime(_now.year, _now.month, _now.day + days);

FakeBackend backend() => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Caja', type: AccountType.cash, balance: 25000),
    testAccount('Dólares', balance: 100, currency: 'USD'),
    testAccount('Vieja', balance: 500, archived: true),
    testAccount(
      'Visa',
      type: AccountType.card,
      balance: -840000,
      creditLimit: 3000000,
      statementDay: daysFromNow(-10).day,
      paymentDay: daysFromNow(5).day,
    ),
  ],
  transactions: [
    testTransaction(
      'banco',
      type: TransactionType.expense,
      accountId: 'id-Bancolombia',
      amount: 50000,
      date: daysFromNow(-1),
      description: 'Pago del banco',
    ),
    testTransaction(
      'efectivo',
      type: TransactionType.expense,
      accountId: 'id-Caja',
      amount: 7000,
      date: daysFromNow(-1),
      description: 'Café en efectivo',
    ),
  ],
);

Finder sheet() => find.byType(AccountDetailSheet);
Finder inSheet(Finder finder) => find.descendant(of: sheet(), matching: finder);

Future<void> openAccounts(WidgetTester tester, {String language = 'es'}) async {
  tallView(tester);
  await pumpMiPlata(tester, backend: backend(), language: language);
  await goTo(tester, AppRoutes.accounts);
}

void main() {
  setUpAll(initDates);

  group('tocar una cuenta', () {
    testWidgets('abre su detalle y no la edición', (tester) async {
      await openAccounts(tester);

      await tester.tap(find.text('Bancolombia'));
      await tester.pumpAndSettle();

      expect(sheet(), findsOneWidget);
      expect(find.byType(AccountFormSheet), findsNothing);
      expect(find.text('Editar cuenta'), findsNothing);
    });

    testWidgets(
      'muestra el nombre, el tipo, el saldo, la moneda y el saldo inicial',
      (tester) async {
        await openAccounts(tester);

        await tester.tap(find.text('Bancolombia'));
        await tester.pumpAndSettle();

        expect(inSheet(find.text('Bancolombia')), findsOneWidget);
        expect(inSheet(find.text('Banco')), findsOneWidget);
        expect(inSheet(find.text('Saldo actual')), findsOneWidget);
        // El saldo ya descuenta el gasto de 50.000.
        expect(inSheet(textLike(r'$950.000')), findsOneWidget);
        expect(inSheet(find.text('COP · Peso colombiano')), findsOneWidget);
        expect(inSheet(find.text('Saldo inicial')), findsOneWidget);
        expect(inSheet(textLike(r'$1.000.000')), findsOneWidget);
      },
    );

    testWidgets('una cuenta en otra moneda lo dice', (tester) async {
      await openAccounts(tester);

      await tester.tap(find.text('Dólares'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('USD · Dólar estadounidense')), findsOneWidget);
      expect(inSheet(textLike(r'US$100')), findsWidgets);
    });

    testWidgets('una cuenta archivada se marca', (tester) async {
      await openAccounts(tester);
      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vieja'));
      await tester.pumpAndSettle();

      expect(inSheet(find.textContaining('Archivada')), findsOneWidget);
    });

    testWidgets(
      'una tarjeta trae su cupo, lo disponible y lo que falta pagar',
      (tester) async {
        await openAccounts(tester);

        await tester.tap(find.text('Visa'));
        await tester.pumpAndSettle();

        expect(inSheet(find.text('Tarjeta')), findsOneWidget);
        expect(inSheet(textLike(r'-$840.000')), findsWidgets);
        expect(
          inSheet(textLike(r'Usado $840.000 de $3.000.000')),
          findsOneWidget,
        );
        expect(inSheet(textLike(r'Disponible $2.160.000')), findsOneWidget);
        expect(
          inSheet(textLike(r'Por pagar del último corte: $840.000')),
          findsOneWidget,
        );
      },
    );

    testWidgets('una cuenta que no es tarjeta no muestra nada de cupo', (
      tester,
    ) async {
      await openAccounts(tester);

      await tester.tap(find.text('Caja'));
      await tester.pumpAndSettle();

      expect(inSheet(find.textContaining('Usado')), findsNothing);
      expect(inSheet(find.textContaining('Disponible')), findsNothing);
    });
  });

  group('desde el detalle', () {
    testWidgets('Editar abre el formulario con los datos', (tester) async {
      await openAccounts(tester);

      await tester.tap(find.text('Bancolombia'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.text('Editar cuenta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Bancolombia'), findsOneWidget);
    });

    testWidgets('Ver movimientos abre Actividad solo con los de esa cuenta', (
      tester,
    ) async {
      await openAccounts(tester);

      await tester.tap(find.text('Bancolombia'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ver movimientos'));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);
      expect(find.text('Pago del banco'), findsOneWidget);
      expect(find.text('Café en efectivo'), findsNothing);
    });

    testWidgets('cerrar el detalle sin elegir no abre nada', (tester) async {
      await openAccounts(tester);

      await tester.tap(find.text('Bancolombia'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.byType(AccountFormSheet), findsNothing);
      expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);
    });

    testWidgets('el menú de la cuenta sigue editando directo', (tester) async {
      await openAccounts(tester);

      await tester.tap(find.byTooltip('Opciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormSheet), findsOneWidget);
      expect(sheet(), findsNothing);
    });
  });

  testWidgets('en inglés, el detalle sale en inglés', (tester) async {
    await openAccounts(tester, language: 'en');

    await tester.tap(find.text('Bancolombia'));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Current balance')), findsOneWidget);
    expect(inSheet(find.text('Initial balance')), findsOneWidget);
    expect(inSheet(find.text('Currency')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'View transactions'),
      findsOneWidget,
    );
  });
}
