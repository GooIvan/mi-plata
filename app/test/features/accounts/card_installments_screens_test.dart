import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/card_installment_plan.dart';
import 'package:mi_plata/features/accounts/presentation/widgets/card_installments_sheet.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime daysFromNow(int days) =>
    DateTime(_now.year, _now.month, _now.day + days);

/// Una cuenta de banco y una tarjeta cuyo último corte fue hace diez días y que
/// se paga dentro de cinco.
FakeBackend withCard() => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 5000000),
    testAccount(
      'Visa',
      type: AccountType.card,
      creditLimit: 5000000,
      statementDay: daysFromNow(-10).day,
      paymentDay: daysFromNow(5).day,
    ),
  ],
  categories: [testCategory('Tecnología', CategoryType.expense)],
);

Finder newMovementButton() =>
    find.widgetWithText(FloatingActionButton, 'Nuevo movimiento');
Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder accountDropdown() => find.byType(DropdownButtonFormField<String>).first;
Finder submit(String label) => find.widgetWithText(FilledButton, label);
Finder deferSwitch() =>
    find.widgetWithText(SwitchListTile, 'Diferir en cuotas');

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> openFormOnVisa(WidgetTester tester) async {
  await tester.tap(newMovementButton());
  await tester.pumpAndSettle();
  await pick(tester, accountDropdown(), 'Visa');
}

void main() {
  setUpAll(initDates);

  group('formulario: diferir en cuotas', () {
    testWidgets('el interruptor solo aparece en un gasto con una tarjeta', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: withCard());
      await tester.tap(newMovementButton());
      await tester.pumpAndSettle();

      // Sin cuenta elegida, o con una cuenta de banco, no hay interruptor.
      expect(deferSwitch(), findsNothing);
      await pick(tester, accountDropdown(), 'Bancolombia');
      expect(deferSwitch(), findsNothing);

      await pick(tester, accountDropdown(), 'Visa');
      expect(deferSwitch(), findsOneWidget);

      // Un ingreso a la tarjeta no se difiere.
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TransactionType>),
          matching: find.text('Ingreso'),
        ),
      );
      await tester.pumpAndSettle();
      expect(deferSwitch(), findsNothing);
    });

    testWidgets(
      'con intereses muestra el total y los intereses antes de guardar',
      (tester) async {
        tallView(tester);
        await pumpMiPlata(tester, backend: withCard());
        await openFormOnVisa(tester);

        await tester.tap(deferSwitch());
        await tester.pumpAndSettle();
        expect(field('Valor de la compra'), findsOneWidget);

        await tester.enterText(field('Valor de la compra'), '1.200.000');
        await tester.enterText(field('Número de cuotas'), '12');
        await tester.enterText(
          field('Valor de cada cuota (opcional)'),
          '125.000',
        );
        await tester.pumpAndSettle();

        expect(
          textLike(
            r'12 cuotas de $125.000. Total a pagar: $1.500.000, con $300.000 de intereses.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('sin valor de cuota no hay intereses', (tester) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: withCard());
      await openFormOnVisa(tester);

      await tester.tap(deferSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field('Valor de la compra'), '1.200.000');
      await tester.enterText(field('Número de cuotas'), '12');
      await tester.pumpAndSettle();

      expect(
        textLike(r'12 cuotas de $100.000. Total a pagar: $1.200.000.'),
        findsOneWidget,
      );
      expect(find.textContaining(' de intereses'), findsNothing);
    });

    testWidgets(
      'registra la compra diferida y la deuda de la tarjeta sube por el total',
      (tester) async {
        tallView(tester);
        final backend = await pumpMiPlata(tester, backend: withCard());
        await openFormOnVisa(tester);

        await tester.tap(deferSwitch());
        await tester.pumpAndSettle();
        await tester.enterText(field('Valor de la compra'), '1.200.000');
        await tester.enterText(field('Número de cuotas'), '12');
        await tester.enterText(
          field('Valor de cada cuota (opcional)'),
          '125.000',
        );
        await tester.enterText(field('Descripción (opcional)'), 'Televisor');
        await tester.tap(submit('Registrar'));
        await tester.pumpAndSettle();

        final draft = backend.installments.created.single;
        expect(draft.accountId, 'id-Visa');
        expect(draft.purchaseAmount, '1200000');
        expect(draft.installments, 12);
        expect(draft.installmentAmount, '125000');
        expect(draft.description, 'Televisor');
        // No pasa por el registro de movimientos de siempre.
        expect(backend.transactions.created, isEmpty);

        // El gasto de la tarjeta es por el total: la deuda sube 1.500.000 y el
        // dinero total de las cuentas no cambia.
        expect(textLike(r'Debes en tarjetas $1.500.000'), findsOneWidget);
      },
    );

    testWidgets('las cuotas y el valor se validan antes de guardar', (
      tester,
    ) async {
      tallView(tester);
      final backend = await pumpMiPlata(tester, backend: withCard());
      await openFormOnVisa(tester);

      await tester.tap(deferSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field('Valor de la compra'), '1.200.000');
      await tester.enterText(field('Número de cuotas'), '1');
      await tester.tap(submit('Registrar'));
      await tester.pump();

      expect(find.text('Escribe de 2 a 60 cuotas'), findsOneWidget);

      // Cuotas que suman muchísimo menos que la compra.
      await tester.enterText(field('Número de cuotas'), '12');
      await tester.enterText(field('Valor de cada cuota (opcional)'), '1');
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Las cuotas no cuadran con el valor de la compra'),
        findsOneWidget,
      );
      expect(backend.installments.created, isEmpty);
    });

    testWidgets('al pasar del cupo avisa, contando lo que se paga en total', (
      tester,
    ) async {
      tallView(tester);
      final backend = await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 5000000),
            testAccount(
              'Visa',
              type: AccountType.card,
              balance: -500000,
              creditLimit: 1000000,
            ),
          ],
        ),
      );
      await openFormOnVisa(tester);

      await tester.tap(deferSwitch());
      await tester.pumpAndSettle();
      // 400.000 de compra en 4 cuotas de 150.000 = 600.000 en total.
      await tester.enterText(field('Valor de la compra'), '400.000');
      await tester.enterText(field('Número de cuotas'), '4');
      await tester.enterText(
        field('Valor de cada cuota (opcional)'),
        '150.000',
      );
      await tester.tap(submit('Registrar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(r'Visa quedaría $100.000 por encima de su cupo.'),
        findsOneWidget,
      );
      expect(backend.installments.created, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar igual'));
      await tester.pumpAndSettle();
      expect(backend.installments.created, hasLength(1));
    });

    testWidgets('en inglés todo el formulario sale en inglés', (tester) async {
      tallView(tester);
      await pumpMiPlata(tester, language: 'en', backend: withCard());
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'New transaction'),
      );
      await tester.pumpAndSettle();
      await pick(tester, accountDropdown(), 'Visa');

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Split into installments'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Purchase price'), '1,200,000');
      await tester.enterText(field('Number of installments'), '12');
      await tester.enterText(
        field('Amount of each installment (optional)'),
        '125,000',
      );
      await tester.pumpAndSettle();

      expect(
        textLike(
          r'12 installments of $125,000. Total to pay: $1,500,000, with $300,000 of interest.',
        ),
        findsOneWidget,
      );
    });
  });

  group('una compra ya diferida', () {
    CardInstallmentPlan installmentPlan() => CardInstallmentPlan(
      id: 'plan-1',
      transactionId: 'tx-tv',
      accountId: 'id-Visa',
      description: 'Televisor',
      date: daysFromNow(-20),
      totalCents: 30000000,
      purchaseCents: 27000000,
      installments: 3,
      installmentCents: 10000000,
    );

    FakeBackend backendWithPurchase() => FakeBackend(
      accounts: [
        testAccount('Bancolombia', balance: 5000000),
        testAccount(
          'Visa',
          type: AccountType.card,
          creditLimit: 5000000,
          statementDay: daysFromNow(-10).day,
          paymentDay: daysFromNow(5).day,
        ),
      ],
      transactions: [
        testTransaction(
          'tx-tv',
          type: TransactionType.expense,
          accountId: 'id-Visa',
          amount: 300000,
          date: daysFromNow(-20),
          description: 'Televisor',
        ),
      ],
      installmentPlans: [installmentPlan()],
    );

    testWidgets('en la lista de movimientos dice en cuántas cuotas es', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backendWithPurchase());

      expect(find.textContaining('3 cuotas · Visa'), findsOneWidget);
    });

    testWidgets('al editarla no se cambia el monto, la tarjeta ni el tipo', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backendWithPurchase());

      await tester.tap(find.text('Televisor').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Compra diferida en 3 cuotas'),
        findsOneWidget,
      );
      final amount = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(amount.enabled, isFalse);
      expect(
        tester
            .widget<SegmentedButton<TransactionType>>(
              find.byType(SegmentedButton<TransactionType>),
            )
            .onSelectionChanged,
        isNull,
      );
      // Y no se ofrece diferirla otra vez.
      expect(deferSwitch(), findsNothing);
    });

    testWidgets('la tarjeta dice lo que se debe del corte y lista la compra', (
      tester,
    ) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backendWithPurchase());
      await goTo(tester, AppRoutes.accounts);

      // Compra de 300.000 en 3 cuotas de 100.000: ya se cobró la primera.
      expect(textLike(r'Por pagar del último corte: $100.000'), findsOneWidget);
      expect(find.text('Compras en cuotas (1)'), findsOneWidget);

      await tester.tap(find.text('Compras en cuotas (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(CardInstallmentsSheet), findsOneWidget);
      final sheet = find.byType(CardInstallmentsSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Televisor')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: textLike(r'3 cuotas · $100.000 cada una'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('1 de 3 cuotas cobradas'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: textLike(r'Faltan $200.000 por cobrar'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('Próxima cuota en el corte del'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('una compra con todas sus cuotas cobradas ya no aparece', (
      tester,
    ) async {
      tallView(tester);
      final finished = CardInstallmentPlan(
        id: 'plan-viejo',
        transactionId: 'tx-viejo',
        accountId: 'id-Visa',
        description: 'Nevera',
        date: daysFromNow(-120),
        totalCents: 30000000,
        purchaseCents: 30000000,
        installments: 3,
        installmentCents: 10000000,
      );
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount(
              'Visa',
              type: AccountType.card,
              statementDay: daysFromNow(-10).day,
              paymentDay: daysFromNow(5).day,
            ),
          ],
          installmentPlans: [finished],
        ),
      );
      await goTo(tester, AppRoutes.accounts);

      expect(find.textContaining('Compras en cuotas'), findsNothing);
    });
  });

  group('activeInstallments', () {
    test('deja las de la tarjeta que siguen cobrándose', () {
      // La tarjeta de siempre: corte el 15. Hoy es 20 de noviembre.
      final visa = testAccount(
        'Visa',
        type: AccountType.card,
        statementDay: 15,
        paymentDay: 30,
      );
      CardInstallmentPlan p(String account, DateTime date) =>
          CardInstallmentPlan(
            id: 'p-$account-$date',
            transactionId: 't',
            accountId: account,
            date: date,
            totalCents: 30000000,
            purchaseCents: 30000000,
            installments: 3,
            installmentCents: 10000000,
          );

      final active = activeInstallments(
        [
          p('id-Visa', DateTime(2026, 10, 20)), // activa
          p('id-Visa', DateTime(2026, 8, 20)), // terminada
          p('id-Otra', DateTime(2026, 10, 20)), // de otra tarjeta
        ],
        visa,
        today: DateTime(2026, 11, 20),
      );

      expect(active, hasLength(1));
      expect(active.single.date, DateTime(2026, 10, 20));
    });
  });
}
