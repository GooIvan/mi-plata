import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/theme/finance_colors.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/account_type_ui.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/dashboard/presentation/widgets/accounts_strip.dart';
import 'package:mi_plata/features/dashboard/presentation/widgets/total_balance_card.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/presentation/widgets/transaction_tile.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

/// El color de fondo de la tarjeta del dinero total (su primer degradado).
List<Color> heroColors(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(TotalBalanceCard),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = box.decoration! as BoxDecoration;
  return (decoration.gradient! as LinearGradient).colors;
}

FakeBackend withMovements({double expenseAmount = 70000}) {
  final now = DateTime.now();
  return FakeBackend(
    accounts: [
      testAccount('Bancolombia', balance: 1000000),
      testAccount('Efectivo', type: AccountType.cash, balance: 200000),
    ],
    categories: [testCategory('Comida', CategoryType.expense)],
    transactions: [
      testTransaction(
        't1',
        type: TransactionType.income,
        accountId: 'id-Bancolombia',
        amount: 3200000,
        date: now,
      ),
      testTransaction(
        't2',
        type: TransactionType.expense,
        accountId: 'id-Efectivo',
        categoryId: 'cat-Comida',
        amount: expenseAmount,
        date: now,
      ),
    ],
  );
}

void main() {
  setUpAll(initDates);

  group('tarjeta del dinero total', () {
    testWidgets('dice cuánto entró y cuánto salió este mes', (tester) async {
      await pumpMiPlata(tester, backend: withMovements());

      final card = find.byType(TotalBalanceCard);
      expect(
        find.descendant(of: card, matching: find.text('Ingresos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: textLike(r'$3.200.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Gastos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: textLike(r'$70.000')),
        findsOneWidget,
      );
    });

    testWidgets('en inglés los rótulos salen en inglés', (tester) async {
      await pumpMiPlata(tester, backend: withMovements(), language: 'en');

      final card = find.byType(TotalBalanceCard);
      expect(
        find.descendant(of: card, matching: find.text('Income')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Expenses')),
        findsOneWidget,
      );
    });

    testWidgets('con un total positivo usa el degradado de la marca', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: withMovements());

      final finance = Theme.of(tester.element(find.byType(TotalBalanceCard)))
          .extension<FinanceColors>()!;
      expect(heroColors(tester), finance.heroGradient);
    });

    testWidgets('con un total en contra la tarjeta se pone roja', (
      tester,
    ) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Visa', type: AccountType.card, balance: -350000),
          ],
        ),
      );

      final finance = Theme.of(tester.element(find.byType(TotalBalanceCard)))
          .extension<FinanceColors>()!;
      expect(heroColors(tester), isNot(finance.heroGradient));
      expect(
        heroColors(tester).first.r,
        greaterThan(heroColors(tester).first.g),
      );
      expect(textLike(r'-$350.000'), findsWidgets);
    });

    testWidgets('sin cuentas invita a crear una y no muestra el mes', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: FakeBackend());

      final card = find.byType(TotalBalanceCard);
      expect(
        find.descendant(of: card, matching: find.text('Crear cuenta')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Ingresos')),
        findsNothing,
      );
    });
  });

  group('cuentas en tarjetas', () {
    testWidgets(
      'cada cuenta activa tiene su tarjeta, con el color de su tipo',
      (tester) async {
        await pumpMiPlata(tester, backend: withMovements());

        final strip = find.byType(AccountsStrip);
        expect(
          find.descendant(of: strip, matching: find.text('Bancolombia')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: strip, matching: find.text('Efectivo')),
          findsOneWidget,
        );

        final brightness = Theme.of(tester.element(strip)).brightness;
        expect(
          AccountType.bank.color(brightness),
          isNot(AccountType.cash.color(brightness)),
        );
      },
    );

    testWidgets(
      'los cuatro tipos tienen colores distintos, en claro y oscuro',
      (tester) async {
        for (final brightness in Brightness.values) {
          final colors = {
            for (final type in AccountType.values) type.color(brightness),
          };
          expect(
            colors.length,
            AccountType.values.length,
            reason: '$brightness',
          );
        }
      },
    );

    testWidgets('al tocar una abre la lista de cuentas', (tester) async {
      await pumpMiPlata(tester, backend: withMovements());

      await tester.tap(
        find.descendant(
          of: find.byType(AccountsStrip),
          matching: find.text('Bancolombia'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);
    });
  });

  group('encabezado', () {
    testWidgets(
      'muestra la marca y la inicial del correo, que lleva a los ajustes',
      (tester) async {
        await pumpMiPlata(tester, backend: withMovements());

        expect(find.text('mi-plata'), findsOneWidget);
        expect(find.widgetWithText(CircleAvatar, 'A'), findsOneWidget);

        await tester.tap(find.byTooltip('ana@correo.com'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
      },
    );
  });

  group('movimientos recientes', () {
    testWidgets('el color del monto dice si entró, salió o se movió', (
      tester,
    ) async {
      tallView(tester);
      final now = DateTime.now();
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('A', balance: 500000),
            testAccount('B', balance: 0),
          ],
          transactions: [
            testTransaction(
              'i',
              type: TransactionType.income,
              accountId: 'id-A',
              amount: 1000,
              date: now,
            ),
            testTransaction(
              'e',
              type: TransactionType.expense,
              accountId: 'id-A',
              amount: 2000,
              date: now,
            ),
            testTransaction(
              't',
              type: TransactionType.transfer,
              accountId: 'id-A',
              destinationAccountId: 'id-B',
              amount: 3000,
              date: now,
            ),
          ],
        ),
      );
      final finance = Theme.of(tester.element(find.byType(TotalBalanceCard)))
          .extension<FinanceColors>()!;

      // Solo en la lista de movimientos: las tarjetas de arriba repiten montos.
      Color? colorOf(String text) => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(TransactionTile),
              matching: textLike(text),
            ),
          )
          .style
          ?.color;

      expect(colorOf(r'+$1.000'), finance.income);
      expect(colorOf(r'-$2.000'), finance.expense);
      expect(colorOf(r'$3.000'), finance.transfer);
    });
  });
}
