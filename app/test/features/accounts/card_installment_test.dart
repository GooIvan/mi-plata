import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/card_calendar.dart';
import 'package:mi_plata/features/accounts/domain/card_installment_draft.dart';
import 'package:mi_plata/features/accounts/domain/card_installment_plan.dart';
import 'package:mi_plata/features/accounts/domain/card_statement.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';

DateTime d(int year, int month, int day) => DateTime(year, month, day);

/// Una compra de [total] (con [purchase] sin intereses) en [installments]
/// cuotas de [each], hecha el [date], con la tarjeta 'id-Visa'.
CardInstallmentPlan plan({
  required DateTime date,
  int installments = 3,
  int each = 10000000,
  int? total,
  int? purchase,
  String accountId = 'id-Visa',
}) => CardInstallmentPlan(
  id: 'plan',
  transactionId: 'tx',
  accountId: accountId,
  date: date,
  totalCents: total ?? each * installments,
  purchaseCents: purchase ?? total ?? each * installments,
  installments: installments,
  installmentCents: each,
);

void main() {
  // Corte el 15, pago hasta el 30.
  const calendar = CardCalendar(statementDay: 15, paymentDay: 30);

  group('CardInstallmentPlan.fromJson', () {
    test('lee una fila de v_card_installment_plans, en centavos', () {
      final parsed = CardInstallmentPlan.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'transaction_id': 't1',
        'account_id': 'a1',
        'category_id': null,
        'description': 'Televisor',
        'transaction_date': '2026-10-20',
        'total_amount': 1500000.00,
        'purchase_amount': 1200000,
        'installments': 12,
        'installment_amount': 125000.5,
      });

      expect(parsed.transactionId, 't1');
      expect(parsed.description, 'Televisor');
      expect(parsed.date, d(2026, 10, 20));
      expect(parsed.totalCents, 150000000);
      expect(parsed.purchaseCents, 120000000);
      expect(parsed.interestCents, 30000000);
      expect(parsed.installments, 12);
      expect(parsed.installmentCents, 12500050);
    });
  });

  group('cuotas', () {
    test('la última cuota es lo que falte para llegar al total', () {
      // 100.000 en 3 cuotas: 33.333,33 las dos primeras y 33.333,34 la última.
      final p = plan(date: d(2026, 10, 20), each: 3333333, total: 10000000);
      expect(p.cuotaCents(1), 3333333);
      expect(p.cuotaCents(2), 3333333);
      expect(p.cuotaCents(3), 3333334);
      expect(p.cuotaCents(1) + p.cuotaCents(2) + p.cuotaCents(3), 10000000);
    });

    test('con intereses, los intereses son lo que pasa de la compra', () {
      final p = plan(
        date: d(2026, 10, 20),
        installments: 12,
        each: 12500000,
        purchase: 120000000,
      );
      expect(p.totalCents, 150000000);
      expect(p.interestCents, 30000000);
    });
  });

  group('lo que ya se cobró', () {
    // Compra del 20 de octubre: la primera cuota entra en el corte del 15 de
    // noviembre. Tres cuotas de 100.000.
    final p = plan(date: d(2026, 10, 20));

    test('antes de su primer corte no se ha cobrado nada', () {
      expect(p.billedCuotas(calendar, d(2026, 10, 15)), 0);
      expect(p.billedCents(calendar, d(2026, 10, 15)), 0);
      expect(p.unbilledCents(calendar, d(2026, 10, 15)), 30000000);
    });

    test('una cuota por corte, hasta llegar al total', () {
      expect(p.billedCuotas(calendar, d(2026, 11, 15)), 1);
      expect(p.billedCents(calendar, d(2026, 11, 15)), 10000000);
      expect(p.unbilledCents(calendar, d(2026, 11, 15)), 20000000);

      expect(p.billedCuotas(calendar, d(2026, 12, 15)), 2);
      expect(p.billedCuotas(calendar, d(2027, 1, 15)), 3);
      expect(p.unbilledCents(calendar, d(2027, 1, 15)), 0);
    });

    test('después de la última, no pasa de las cuotas pactadas', () {
      expect(p.billedCuotas(calendar, d(2027, 2, 15)), 3);
      expect(p.billedCents(calendar, d(2027, 6, 15)), 30000000);
      expect(p.unbilledCents(calendar, d(2027, 6, 15)), 0);
    });

    test(
      'cuando se cobra la última, se cobra lo que faltaba (con los centavos)',
      () {
        final p = plan(date: d(2026, 10, 20), each: 3333333, total: 10000000);
        expect(p.billedCents(calendar, d(2026, 12, 15)), 6666666);
        expect(p.billedCents(calendar, d(2027, 1, 15)), 10000000);
      },
    );

    test('una compra el día del corte entra en ese corte; al día siguiente, en el otro', () {
      expect(
        plan(date: d(2026, 11, 15)).billedCuotas(calendar, d(2026, 11, 15)),
        1,
      );
      expect(
        plan(date: d(2026, 11, 16)).billedCuotas(calendar, d(2026, 11, 15)),
        0,
      );
      expect(
        plan(date: d(2026, 11, 16)).billedCuotas(calendar, d(2026, 12, 15)),
        1,
      );
    });

    test('cruza el cambio de año', () {
      final p = plan(date: d(2026, 12, 20), installments: 4);
      // Primera cuota en el corte del 15 de enero.
      expect(p.billedCuotas(calendar, d(2026, 12, 15)), 0);
      expect(p.billedCuotas(calendar, d(2027, 1, 15)), 1);
      expect(p.billedCuotas(calendar, d(2027, 4, 15)), 4);
    });

    test('con un corte el 31, los meses cortos cuentan igual', () {
      const end = CardCalendar(statementDay: 31, paymentDay: 10);
      final p = plan(date: d(2026, 1, 20), installments: 3);
      // Cortes: 31 ene, 28 feb, 31 mar.
      expect(p.billedCuotas(end, d(2026, 1, 31)), 1);
      expect(p.billedCuotas(end, d(2026, 2, 28)), 2);
      expect(p.billedCuotas(end, d(2026, 3, 31)), 3);
    });
  });

  group('terminada y próxima cuota', () {
    final p = plan(date: d(2026, 10, 20));

    test('sigue activa hasta que se cobra la última cuota', () {
      expect(p.isFinished(calendar, d(2026, 11, 20)), isFalse);
      expect(p.isFinished(calendar, d(2027, 1, 10)), isFalse);
      expect(p.isFinished(calendar, d(2027, 1, 15)), isTrue);
      expect(p.isFinished(calendar, d(2027, 3, 1)), isTrue);
    });

    test('la próxima cuota entra en el siguiente corte', () {
      expect(p.nextCuotaStatement(calendar, d(2026, 10, 25)), d(2026, 11, 15));
      expect(p.nextCuotaStatement(calendar, d(2026, 11, 20)), d(2026, 12, 15));
      expect(p.nextCuotaStatement(calendar, d(2026, 12, 20)), d(2027, 1, 15));
      expect(p.nextCuotaStatement(calendar, d(2027, 1, 20)), isNull);
    });
  });

  group('CardInstallmentQuote', () {
    CardInstallmentQuote quote(int purchase, int count, {int? each}) =>
        CardInstallmentQuote.of(
          purchaseCents: purchase,
          installments: count,
          installmentCents: each,
        );

    test('sin valor de cuota no hay intereses: se parte en partes iguales', () {
      final q = quote(120000000, 12);
      expect(q.valid, isTrue);
      expect(q.installmentCents, 10000000);
      expect(q.totalCents, 120000000);
    });

    test('la compra que no se parte exacto no cambia el total', () {
      final q = quote(10000000, 3);
      expect(q.installmentCents, 3333333);
      expect(q.totalCents, 10000000);
      expect(q.valid, isTrue);
    });

    test('con valor de cuota, el total son las cuotas completas', () {
      final q = quote(120000000, 12, each: 12500000);
      expect(q.valid, isTrue);
      expect(q.installmentCents, 12500000);
      expect(q.totalCents, 150000000);
    });

    test('cuotas que suman menos que la compra se rechazan', () {
      // 12 cuotas de $1 para una compra de $1.200.000.
      expect(quote(120000000, 12, each: 100).valid, isFalse);
      expect(quote(120000000, 12, each: 9000000).valid, isFalse);
    });

    test('los centavos del redondeo no cuentan como error', () {
      // 100.000 / 3 redondeado a la baja: 33.333,33 × 3 = 99.999,99.
      final q = quote(10000000, 3, each: 3333333);
      expect(q.valid, isTrue);
      expect(q.totalCents, 10000000);
    });

    test('hacen falta al menos dos cuotas y una compra con valor', () {
      expect(quote(10000000, 1).valid, isFalse);
      expect(quote(0, 3).valid, isFalse);
      expect(quote(10000000, 0).valid, isFalse);
    });
  });

  group('CardInstallmentDraft', () {
    test('arma los parámetros de la función de la base de datos', () {
      final draft = CardInstallmentDraft(
        accountId: 'a1',
        purchaseAmount: '1200000',
        installments: 12,
        installmentAmount: '125000',
        categoryId: 'c1',
        date: d(2026, 10, 5),
        description: 'Televisor',
      );

      expect(draft.toRpcParams(), {
        'p_account_id': 'a1',
        'p_purchase_amount': '1200000',
        'p_installments': 12,
        'p_installment_amount': '125000',
        'p_category_id': 'c1',
        'p_date': '2026-10-05',
        'p_description': 'Televisor',
      });
    });

    test('lo que no se indica va como nulo', () {
      final params = CardInstallmentDraft(
        accountId: 'a1',
        purchaseAmount: '100',
        installments: 2,
        date: d(2026, 10, 5),
      ).toRpcParams();

      expect(params['p_installment_amount'], isNull);
      expect(params['p_category_id'], isNull);
      expect(params['p_description'], isNull);
    });
  });

  group('CardStatement con compras en cuotas', () {
    // Hoy es 20 de noviembre: el último corte fue el 15 y se paga hasta el 30.
    final today = d(2026, 11, 20);

    test('solo la cuota cobrada entra en lo que se debe del extracto', () {
      // Compra del 20 de octubre, 3 cuotas de 100.000: ya se cobró la primera.
      // La deuda de hoy son los 300.000 de la compra.
      final statement = CardStatement.compute(
        account: testAccount(
          'Visa',
          type: AccountType.card,
          balance: -300000,
          statementDay: 15,
          paymentDay: 30,
        ),
        sinceStatement: const [],
        today: today,
        plans: [plan(date: d(2026, 10, 20))],
      )!;

      expect(statement.debtCents, 30000000);
      expect(statement.dueCents, 10000000);
      expect(statement.unbilledCents, 20000000);
    });

    test(
      'una compra en cuotas hecha después del corte no se cobra todavía',
      () {
        // Compra del 18 de noviembre: entra completa como gasto nuevo.
        final purchase = testTransaction(
          'tx',
          type: TransactionType.expense,
          accountId: 'id-Visa',
          amount: 300000,
          date: d(2026, 11, 18),
        );
        final statement = CardStatement.compute(
          account: testAccount(
            'Visa',
            type: AccountType.card,
            balance: -300000,
            statementDay: 15,
            paymentDay: 30,
          ),
          sinceStatement: [purchase],
          today: today,
          plans: [plan(date: d(2026, 11, 18))],
        )!;

        // No se cuenta dos veces: ni por el gasto ni por el plan.
        expect(statement.dueCents, 0);
        expect(statement.isPaidUp, isTrue);
      },
    );

    test('suma las cuotas cobradas a lo demás que se debe del corte', () {
      // Se debían 150.000 de compras normales antes del corte, más la cuota.
      final statement = CardStatement.compute(
        account: testAccount(
          'Visa',
          type: AccountType.card,
          balance: -450000,
          statementDay: 15,
          paymentDay: 30,
        ),
        sinceStatement: const [],
        today: today,
        plans: [plan(date: d(2026, 10, 20))],
      )!;

      expect(statement.dueCents, 25000000); // 150.000 + 100.000
    });

    test(
      'al pagar el extracto, las cuotas por cobrar siguen sin deberse todavía',
      () {
        // Se pagaron los 100.000 de la cuota: la deuda baja a 200.000, todo por
        // cobrar en los próximos extractos.
        final statement = CardStatement.compute(
          account: testAccount(
            'Visa',
            type: AccountType.card,
            balance: -200000,
            statementDay: 15,
            paymentDay: 30,
          ),
          sinceStatement: [
            testTransaction(
              'pago',
              type: TransactionType.transfer,
              accountId: 'id-Banco',
              destinationAccountId: 'id-Visa',
              amount: 100000,
              date: d(2026, 11, 17),
            ),
          ],
          today: today,
          plans: [plan(date: d(2026, 10, 20))],
        )!;

        expect(statement.dueCents, 0);
        expect(statement.debtCents, 20000000);
      },
    );

    test('una compra ya terminada no suma nada por cobrar', () {
      // Compra de agosto en 3 cuotas: cobradas en sept, oct y nov.
      final statement = CardStatement.compute(
        account: testAccount(
          'Visa',
          type: AccountType.card,
          balance: -100000,
          statementDay: 15,
          paymentDay: 30,
        ),
        sinceStatement: const [],
        today: today,
        plans: [plan(date: d(2026, 8, 20))],
      )!;

      expect(statement.dueCents, 10000000);
    });

    test('las compras en cuotas de otra tarjeta no cuentan', () {
      final statement = CardStatement.compute(
        account: testAccount(
          'Visa',
          type: AccountType.card,
          balance: -100000,
          statementDay: 15,
          paymentDay: 30,
        ),
        sinceStatement: const [],
        today: today,
        plans: [plan(date: d(2026, 10, 20), accountId: 'id-Otra')],
      )!;

      expect(statement.dueCents, 10000000);
    });
  });
}
