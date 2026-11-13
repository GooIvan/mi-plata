import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/card_installment_plan.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_form_screen.dart';
import 'package:mi_plata/features/transactions/presentation/widgets/transaction_detail_sheet.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _day = DateTime(2026, 10, 14);

FakeBackend backend({
  List<CardInstallmentPlan> plans = const [],
  String baseCurrency = 'COP',
}) => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Nequi', type: AccountType.wallet, balance: 50000),
    testAccount('Dólares', balance: 100, currency: 'USD'),
    testAccount('Visa', type: AccountType.card, balance: -300000),
  ],
  categories: [
    testCategory('Mercado', CategoryType.expense),
    testCategory('Salario', CategoryType.income),
  ],
  transactions: [
    testTransaction(
      'gasto',
      type: TransactionType.expense,
      accountId: 'id-Bancolombia',
      categoryId: 'cat-Mercado',
      amount: 120000,
      date: _day,
      description: 'Compra semanal',
    ),
    testTransaction(
      'ingreso',
      type: TransactionType.income,
      accountId: 'id-Bancolombia',
      categoryId: 'cat-Salario',
      amount: 3000000,
      date: DateTime(2026, 10, 10),
      description: 'Sueldo de octubre',
    ),
    testTransaction(
      'sin-nada',
      type: TransactionType.expense,
      accountId: 'id-Nequi',
      amount: 8000,
      date: DateTime(2026, 10, 9),
    ),
    testTransaction(
      'transferencia',
      type: TransactionType.transfer,
      accountId: 'id-Bancolombia',
      destinationAccountId: 'id-Nequi',
      amount: 50000,
      date: DateTime(2026, 10, 8),
      description: 'Para el mercado',
    ),
    testTransaction(
      'entre-monedas',
      type: TransactionType.transfer,
      accountId: 'id-Bancolombia',
      destinationAccountId: 'id-Dólares',
      amount: 400000,
      destinationAmount: 100,
      date: DateTime(2026, 10, 7),
      description: 'Cambio de dólares',
    ),
    testTransaction(
      'tv',
      type: TransactionType.expense,
      accountId: 'id-Visa',
      amount: 300000,
      date: DateTime(2026, 10, 6),
      description: 'Televisor',
    ),
  ],
  installmentPlans: plans,
);

Finder sheet() => find.byType(TransactionDetailSheet);
Finder inSheet(Finder finder) => find.descendant(of: sheet(), matching: finder);

Future<void> openActivity(
  WidgetTester tester, {
  FakeBackend? fakes,
  String language = 'es',
}) async {
  tallView(tester);
  await pumpMiPlata(tester, backend: fakes ?? backend(), language: language);
  await goTo(tester, AppRoutes.transactions);
}

void main() {
  setUpAll(initDates);

  group('tocar un movimiento', () {
    testWidgets('abre su detalle y no la edición', (tester) async {
      await openActivity(tester);

      await tester.tap(find.text('Compra semanal'));
      await tester.pumpAndSettle();

      expect(sheet(), findsOneWidget);
      expect(find.byType(TransactionFormScreen), findsNothing);
      expect(find.text('Editar movimiento'), findsNothing);
    });

    testWidgets(
      'muestra el monto, la fecha, la cuenta, la categoría y la descripción',
      (tester) async {
        await openActivity(tester);

        await tester.tap(find.text('Compra semanal'));
        await tester.pumpAndSettle();

        expect(inSheet(find.text('Gasto')), findsOneWidget);
        expect(inSheet(textLike(r'-$120.000')), findsOneWidget);
        expect(inSheet(find.text('14 de octubre de 2026')), findsOneWidget);
        expect(inSheet(find.text('Bancolombia')), findsOneWidget);
        expect(inSheet(find.text('Mercado')), findsOneWidget);
        expect(inSheet(find.text('Compra semanal')), findsOneWidget);
      },
    );

    testWidgets('un ingreso lleva el signo más', (tester) async {
      await openActivity(tester);

      await tester.tap(find.text('Sueldo de octubre'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Ingreso')), findsOneWidget);
      expect(inSheet(textLike(r'+$3.000.000')), findsOneWidget);
      expect(inSheet(find.text('Salario')), findsOneWidget);
    });

    testWidgets('sin categoría ni descripción lo dice y no inventa filas', (
      tester,
    ) async {
      await openActivity(tester);

      await tester.tap(find.text('Gasto').first);
      await tester.pumpAndSettle();

      // El gasto de Nequi no tiene ninguna de las dos.
      expect(inSheet(find.text('Sin categoría')), findsOneWidget);
      expect(inSheet(find.text('Descripción')), findsNothing);
    });

    testWidgets('una transferencia dice de dónde sale y a dónde llega', (
      tester,
    ) async {
      await openActivity(tester);

      await tester.tap(find.text('Para el mercado'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Transferencia')), findsOneWidget);
      expect(inSheet(find.text('Desde')), findsOneWidget);
      expect(inSheet(find.text('Hacia')), findsOneWidget);
      expect(inSheet(find.text('Bancolombia')), findsOneWidget);
      expect(inSheet(find.text('Nequi')), findsOneWidget);
      // Una transferencia no tiene categoría.
      expect(inSheet(find.text('Categoría')), findsNothing);
      expect(inSheet(textLike(r'$50.000')), findsOneWidget);
    });

    testWidgets('entre monedas distintas también dice lo que llegó', (
      tester,
    ) async {
      await openActivity(tester);

      await tester.tap(find.text('Cambio de dólares'));
      await tester.pumpAndSettle();

      expect(inSheet(textLike(r'$400.000')), findsOneWidget);
      expect(
        inSheet(find.textContaining('Llega a la cuenta de destino')),
        findsOneWidget,
      );
      expect(inSheet(find.textContaining('100')), findsWidgets);
    });

    testWidgets(
      'una compra diferida en cuotas dice cuántas, de cuánto y los intereses',
      (tester) async {
        await openActivity(
          tester,
          fakes: backend(
            plans: [
              CardInstallmentPlan(
                id: 'p',
                transactionId: 'tv',
                accountId: 'id-Visa',
                description: 'Televisor',
                date: DateTime(2026, 10, 6),
                totalCents: 30000000,
                purchaseCents: 27000000,
                installments: 3,
                installmentCents: 10000000,
              ),
            ],
          ),
        );

        await tester.tap(find.text('Televisor'));
        await tester.pumpAndSettle();

        expect(inSheet(find.text('Compras en cuotas')), findsOneWidget);
        expect(
          inSheet(
            textLike(
              r'3 cuotas de $100.000. Total a pagar: $300.000, con $30.000 de intereses.',
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('una compra sin cuotas no muestra esa fila', (tester) async {
      await openActivity(tester);

      await tester.tap(find.text('Televisor'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Compras en cuotas')), findsNothing);
    });
  });

  group('editar desde el detalle', () {
    testWidgets('el botón Editar abre el formulario con los datos', (
      tester,
    ) async {
      await openActivity(tester);

      await tester.tap(find.text('Compra semanal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '120000'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Compra semanal'),
        findsOneWidget,
      );
    });

    testWidgets('cerrar el detalle sin editar no abre nada', (tester) async {
      await openActivity(tester);

      await tester.tap(find.text('Compra semanal'));
      await tester.pumpAndSettle();
      // Tocar fuera cierra la hoja.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.byType(TransactionFormScreen), findsNothing);
    });

    testWidgets('lo editado se ve en la lista al volver', (tester) async {
      await openActivity(tester);

      await openMovementForEdit(tester, find.text('Compra semanal'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Compra semanal'),
        'Compra del mes',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Compra del mes'), findsOneWidget);
    });
  });

  group('desde otras pantallas', () {
    testWidgets('en Inicio, tocar un movimiento también abre el detalle', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backend());

      await tester.tap(find.text('Compra semanal'));
      await tester.pumpAndSettle();

      expect(sheet(), findsOneWidget);
      expect(find.byType(TransactionFormScreen), findsNothing);
    });
  });

  testWidgets('en inglés, el detalle sale en inglés', (tester) async {
    await openActivity(tester, language: 'en');

    await tester.tap(find.text('Compra semanal'));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Expense')), findsOneWidget);
    expect(inSheet(find.text('Date')), findsOneWidget);
    expect(inSheet(find.text('Account')), findsOneWidget);
    expect(inSheet(find.text('Category')), findsOneWidget);
    expect(inSheet(find.text('Description')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
  });
}
