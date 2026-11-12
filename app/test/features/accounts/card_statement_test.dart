import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/card_statement.dart';
import 'package:mi_plata/features/accounts/presentation/card_actions.dart';
import 'package:mi_plata/features/dashboard/presentation/widgets/card_payments_card.dart';
import 'package:mi_plata/features/transactions/domain/credit_limit_check.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

DateTime d(int year, int month, int day) => DateTime(year, month, day);

/// La tarjeta de siempre: corte el 15, pago hasta el 30.
Account visa({
  double balance = 0,
  double? limit,
  String currency = 'COP',
  bool archived = false,
}) => testAccount(
  'Visa',
  type: AccountType.card,
  balance: balance,
  creditLimit: limit,
  statementDay: 15,
  paymentDay: 30,
  currency: currency,
  archived: archived,
);

void main() {
  setUpAll(initDates);

  group('CardStatement.compute', () {
    // Hoy es 20 de noviembre: el último corte fue el 15 y se paga hasta el 30.
    final today = d(2026, 11, 20);

    Account owing(double debt) => visa(balance: -debt);

    test('sin nada nuevo desde el corte, se debe todo', () {
      final statement = CardStatement.compute(
        account: owing(840000),
        sinceStatement: const [],
        today: today,
      )!;

      expect(statement.statementDate, d(2026, 11, 15));
      expect(statement.dueDate, d(2026, 11, 30));
      expect(statement.debtCents, 84000000);
      expect(statement.dueCents, 84000000);
      expect(statement.unbilledCents, 0);
      expect(statement.isPaidUp, isFalse);
    });

    test('lo gastado después del corte todavía no se cobra', () {
      // La deuda de hoy ya incluye la compra del 18 de nov (100.000).
      final statement = CardStatement.compute(
        account: owing(840000),
        sinceStatement: [
          testTransaction(
            't1',
            type: TransactionType.expense,
            accountId: 'id-Visa',
            amount: 100000,
            date: d(2026, 11, 18),
          ),
        ],
        today: today,
      )!;

      expect(statement.debtCents, 84000000);
      expect(statement.unbilledCents, 10000000);
      expect(statement.dueCents, 74000000);
    });

    test('un pago después del corte baja lo que falta del extracto', () {
      // Se debía 840.000; se pagaron 300.000 el 17 y se gastaron 100.000 el 18.
      // La deuda de hoy es 640.000: 100.000 son del próximo extracto.
      final statement = CardStatement.compute(
        account: owing(640000),
        sinceStatement: [
          testTransaction(
            'pago',
            type: TransactionType.transfer,
            accountId: 'id-Banco',
            destinationAccountId: 'id-Visa',
            amount: 300000,
            date: d(2026, 11, 17),
          ),
          testTransaction(
            'compra',
            type: TransactionType.expense,
            accountId: 'id-Visa',
            amount: 100000,
            date: d(2026, 11, 18),
          ),
        ],
        today: today,
      )!;

      expect(statement.dueCents, 54000000);
    });

    test(
      'pagar todo el extracto lo deja al día, aunque haya compras nuevas',
      () {
        final statement = CardStatement.compute(
          account: owing(100000),
          sinceStatement: [
            testTransaction(
              'pago',
              type: TransactionType.transfer,
              accountId: 'id-Banco',
              destinationAccountId: 'id-Visa',
              amount: 840000,
              date: d(2026, 11, 17),
            ),
            testTransaction(
              'compra',
              type: TransactionType.expense,
              accountId: 'id-Visa',
              amount: 100000,
              date: d(2026, 11, 18),
            ),
          ],
          today: today,
        )!;

        expect(statement.dueCents, 0);
        expect(statement.isPaidUp, isTrue);
        expect(statement.isOverdue(d(2026, 12, 5)), isFalse);
      },
    );

    test('pagar de más no deja un saldo por pagar', () {
      final statement = CardStatement.compute(
        account: visa(balance: 50000),
        sinceStatement: const [],
        today: today,
      )!;
      expect(statement.debtCents, 0);
      expect(statement.dueCents, 0);
    });

    test('lo anterior al corte se ignora; el mismo día del corte, también', () {
      final statement = CardStatement.compute(
        account: owing(500000),
        sinceStatement: [
          testTransaction(
            'antes',
            type: TransactionType.expense,
            accountId: 'id-Visa',
            amount: 70000,
            date: d(2026, 11, 14),
          ),
          testTransaction(
            'el día del corte',
            type: TransactionType.expense,
            accountId: 'id-Visa',
            amount: 30000,
            date: d(2026, 11, 15),
          ),
        ],
        today: today,
      )!;

      expect(statement.dueCents, 50000000);
    });

    test(
      'un adelanto (una transferencia que sale de la tarjeta) es un cobro',
      () {
        final statement = CardStatement.compute(
          account: owing(300000),
          sinceStatement: [
            testTransaction(
              'adelanto',
              type: TransactionType.transfer,
              accountId: 'id-Visa',
              destinationAccountId: 'id-Banco',
              amount: 100000,
              date: d(2026, 11, 18),
            ),
          ],
          today: today,
        )!;

        expect(statement.dueCents, 20000000);
      },
    );

    test('un reembolso (un ingreso) no cuenta como cobro nuevo', () {
      // Se devolvieron 50.000: la deuda de hoy ya los descontó.
      final statement = CardStatement.compute(
        account: owing(450000),
        sinceStatement: [
          testTransaction(
            'reembolso',
            type: TransactionType.income,
            accountId: 'id-Visa',
            amount: 50000,
            date: d(2026, 11, 18),
          ),
        ],
        today: today,
      )!;

      expect(statement.dueCents, 45000000);
    });

    test('sin días de corte y de pago no hay extracto', () {
      expect(
        CardStatement.compute(
          account: testAccount('Visa', type: AccountType.card, balance: -1),
          sinceStatement: const [],
          today: today,
        ),
        isNull,
      );
      expect(
        CardStatement.compute(
          account: testAccount('Banco', statementDay: null),
          sinceStatement: const [],
          today: today,
        ),
        isNull,
      );
    });

    test('vencido: falta pagar algo y la fecha límite ya pasó', () {
      final statement = CardStatement.compute(
        account: owing(100000),
        sinceStatement: const [],
        today: today,
      )!;

      expect(statement.isOverdue(d(2026, 11, 30)), isFalse);
      expect(statement.isOverdue(d(2026, 12, 1)), isTrue);
      expect(statement.daysUntilDue(d(2026, 11, 20)), 10);
      expect(statement.daysUntilDue(d(2026, 11, 30)), 0);
      expect(statement.daysUntilDue(d(2026, 12, 2)), -2);
    });

    test('cuenta los días sin que importe la hora ni el cambio de horario', () {
      final statement = CardStatement.compute(
        account: owing(100000),
        sinceStatement: const [],
        today: today,
      )!;
      expect(statement.daysUntilDue(DateTime(2026, 11, 29, 23, 59)), 1);
    });

    test('en centavos enteros, sin error de coma flotante', () {
      final statement = CardStatement.compute(
        account: owing(0.1 + 0.2),
        sinceStatement: const [],
        today: today,
      )!;
      expect(statement.dueCents, 30);
    });
  });

  group('CreditLimitCheck', () {
    TransactionDraft spend(String account, String amount) => TransactionDraft(
      type: TransactionType.expense,
      accountId: account,
      amount: amount,
      date: d(2026, 11, 20),
    );

    test('avisa cuando un gasto deja la tarjeta por encima del cupo', () {
      final card = visa(balance: -800000, limit: 1000000);
      final warnings = CreditLimitCheck.after(
        accounts: [card],
        draft: spend(card.id, '300000'),
      );

      expect(warnings, hasLength(1));
      expect(warnings.single.account.name, 'Visa');
      expect(warnings.single.overCents, 10000000);
    });

    test('justo en el cupo no avisa', () {
      final card = visa(balance: -800000, limit: 1000000);
      expect(
        CreditLimitCheck.after(
          accounts: [card],
          draft: spend(card.id, '200000'),
        ),
        isEmpty,
      );
    });

    test('sin cupo no hay nada que avisar', () {
      final card = visa(balance: -800000);
      expect(
        CreditLimitCheck.after(
          accounts: [card],
          draft: spend(card.id, '999999999'),
        ),
        isEmpty,
      );
    });

    test('un pago a una tarjeta que ya estaba pasada no vuelve a avisar', () {
      final card = visa(balance: -1200000, limit: 1000000);
      final payment = TransactionDraft(
        type: TransactionType.transfer,
        accountId: 'id-Banco',
        destinationAccountId: card.id,
        amount: '100000',
        date: d(2026, 11, 20),
      );
      expect(CreditLimitCheck.after(accounts: [card], draft: payment), isEmpty);
    });

    test('un gasto en otra cuenta, o en una tarjeta archivada, no cuenta', () {
      final card = visa(balance: -800000, limit: 1000000);
      final bank = testAccount('Banco', balance: 5000000);
      expect(
        CreditLimitCheck.after(
          accounts: [card, bank],
          draft: spend(bank.id, '9000000'),
        ),
        isEmpty,
      );
      final archived = visa(balance: -800000, limit: 1000000, archived: true);
      expect(
        CreditLimitCheck.after(
          accounts: [archived],
          draft: spend(archived.id, '900000'),
        ),
        isEmpty,
      );
    });

    test('al editar un gasto cuenta solo lo que cambia', () {
      // La deuda de 990.000 ya incluye el gasto de 100.000 que se edita.
      final card = visa(balance: -990000, limit: 1000000);
      final previous = testTransaction(
        't1',
        type: TransactionType.expense,
        accountId: card.id,
        amount: 100000,
        date: d(2026, 11, 20),
      );
      // De 100.000 a 120.000: la deuda sube 20.000 y pasa del cupo por 10.000.
      final warnings = CreditLimitCheck.after(
        accounts: [card],
        draft: spend(card.id, '120000'),
        previous: previous,
      );
      expect(warnings.single.overCents, 1000000);
      // De 100.000 a 105.000: sigue dentro del cupo (995.000 ya está dentro).
      expect(
        CreditLimitCheck.after(
          accounts: [card],
          draft: spend(card.id, '105000'),
          previous: previous,
        ),
        isEmpty,
      );
      // De 100.000 a 50.000: baja la deuda; no avisa.
      expect(
        CreditLimitCheck.after(
          accounts: [card],
          draft: spend(card.id, '50000'),
          previous: previous,
        ),
        isEmpty,
      );
    });
  });

  group('suggestedPayer', () {
    final visaCard = visa();

    test('la cuenta activa de la misma moneda con más dinero', () {
      final payer = suggestedPayer([
        visaCard,
        testAccount('Nequi', balance: 50000),
        testAccount('Bancolombia', balance: 900000),
        testAccount('Efectivo', balance: 10000),
      ], visaCard);
      expect(payer?.name, 'Bancolombia');
    });

    test('no sugiere otra tarjeta, una archivada ni una de otra moneda', () {
      expect(
        suggestedPayer([
          visaCard,
          testAccount('Mastercard', type: AccountType.card, balance: 999999),
          testAccount('Vieja', balance: 999999, archived: true),
          testAccount('Dólares', balance: 999999, currency: 'USD'),
        ], visaCard),
        isNull,
      );
    });
  });

  // Las pruebas con pantallas usan fechas relativas a hoy: el corte fue hace
  // diez días y el pago vence dentro de cinco.
  group('pantallas', () {
    final now = DateTime.now();
    DateTime daysFromNow(int days) =>
        DateTime(now.year, now.month, now.day + days);

    Account cardCutoffAgo({
      double balance = 0,
      int paymentInDays = 5,
      String name = 'Visa',
    }) => testAccount(
      name,
      type: AccountType.card,
      balance: balance,
      creditLimit: 3000000,
      statementDay: daysFromNow(-10).day,
      paymentDay: daysFromNow(paymentInDays).day,
    );

    Future<void> openAccounts(WidgetTester tester, FakeBackend backend) async {
      tallView(tester);
      await pumpMiPlata(tester, backend: backend);
      await goTo(tester, AppRoutes.accounts);
    }

    testWidgets(
      'la tarjeta dice lo que falta pagar y se puede pagar desde ahí',
      (tester) async {
        final backend = FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 2000000),
            cardCutoffAgo(balance: -840000),
          ],
          transactions: [
            testTransaction(
              'compra',
              type: TransactionType.expense,
              accountId: 'id-Visa',
              amount: 100000,
              date: daysFromNow(-2),
            ),
          ],
        );
        await openAccounts(tester, backend);

        // La deuda de hoy: 840.000 + 100.000; lo del próximo extracto, 100.000.
        expect(
          textLike(r'Por pagar del último corte: $840.000'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Pagar'));
        await tester.pumpAndSettle();

        // Abre una transferencia de la cuenta con más dinero hacia la tarjeta,
        // con lo que se debe ya escrito.
        expect(find.text('Desde'), findsWidgets);
        expect(find.widgetWithText(TextFormField, '840000'), findsOneWidget);
        expect(find.textContaining('Bancolombia'), findsWidgets);
      },
    );

    testWidgets('con todo pagado dice que está al día', (tester) async {
      await openAccounts(
        tester,
        FakeBackend(accounts: [cardCutoffAgo(balance: 0)]),
      );

      expect(find.text('Al día con el último corte'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pagar'), findsNothing);
    });

    testWidgets(
      'una fecha límite pasada se marca como vencida, con ícono y texto',
      (tester) async {
        await openAccounts(
          tester,
          FakeBackend(
            accounts: [cardCutoffAgo(balance: -500000, paymentInDays: -2)],
          ),
        );

        expect(find.textContaining('Vencido desde el'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsWidgets);
      },
    );

    testWidgets(
      'Inicio avisa de las tarjetas por pagar, la más urgente primero',
      (tester) async {
        final backend = FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 2000000),
            cardCutoffAgo(balance: -300000, name: 'Visa', paymentInDays: 9),
            cardCutoffAgo(
              balance: -120000,
              name: 'Mastercard',
              paymentInDays: 3,
            ),
            cardCutoffAgo(balance: 0, name: 'Amex'),
          ],
        );
        tallView(tester);
        await pumpMiPlata(tester, backend: backend);

        expect(find.text('Pagos de tarjetas'), findsOneWidget);
        final card = find.byType(CardPaymentsCard);
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text('Amex')),
          findsNothing,
        );

        // Mastercard vence antes que Visa.
        final mastercard = tester.getTopLeft(
          find.descendant(of: card, matching: find.text('Mastercard')),
        );
        final visaTop = tester.getTopLeft(
          find.descendant(of: card, matching: find.text('Visa')),
        );
        expect(mastercard.dy, lessThan(visaTop.dy));
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('Vence en 3 días'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('todo sale en inglés con la app en inglés', (tester) async {
      tallView(tester);
      await pumpMiPlata(
        tester,
        language: 'en',
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 2000000),
            cardCutoffAgo(balance: -300000, paymentInDays: 4),
          ],
        ),
      );

      expect(find.text('Card payments'), findsOneWidget);
      expect(find.textContaining('Due in 4 days'), findsOneWidget);
      expect(find.textContaining('Owed on cards'), findsOneWidget);

      await goTo(tester, AppRoutes.accounts);
      expect(find.textContaining('Used'), findsOneWidget);
      expect(find.textContaining('available'), findsOneWidget);
      expect(find.textContaining('Statement'), findsOneWidget);
      expect(find.textContaining('Due from the last statement'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
      // Nada en español.
      expect(find.textContaining('Usado'), findsNothing);
      expect(find.textContaining('Pagar'), findsNothing);
      expect(find.textContaining('Disponible'), findsNothing);
    });

    testWidgets('Inicio no muestra nada si no hay tarjetas por pagar', (
      tester,
    ) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 100000),
            cardCutoffAgo(),
          ],
        ),
      );

      expect(find.text('Pagos de tarjetas'), findsNothing);
    });
  });
}
