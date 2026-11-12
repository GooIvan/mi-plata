import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_totals.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/summary/domain/balance_history.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

AccountFlow flow(
  DateTime month,
  String accountId,
  int cents, {
  String currency = 'COP',
}) => AccountFlow(
  month: month,
  accountId: accountId,
  currency: currency,
  cents: cents,
);

DateTime m(int year, int month) => DateTime(year, month);

List<int> centsOf(List<BalancePoint> points) => points.map((p) => p.cents).toList();

void main() {
  // Banco empieza con 1.000.000 y Efectivo con 50.000.
  final bank = testAccount('Banco', balance: 1000000);
  final cash = testAccount('Efectivo', balance: 50000);

  group('AccountFlow.fromJson', () {
    test('lee una fila de v_monthly_account_flows, en centavos', () {
      final parsed = AccountFlow.fromJson({
        'user_id': 'u1',
        'month': '2026-02-01',
        'account_id': 'a1',
        'currency': 'COP',
        'flow': -230000.5,
      });

      expect(parsed.month, DateTime(2026, 2));
      expect(parsed.accountId, 'a1');
      expect(parsed.cents, -23000050);
    });

    test('un entero también sirve', () {
      expect(
        AccountFlow.fromJson({
          'month': '2026-01-01',
          'account_id': 'a1',
          'currency': 'COP',
          'flow': 380000,
        }).cents,
        38000000,
      );
    });
  });

  group('BalanceHistory.compute', () {
    // Ene: Banco +380.000. Feb: Banco -230.000 y Efectivo +200.000 (una
    // transferencia de 200.000 y un gasto de 30.000). Mar: Efectivo -25.000.
    final flows = [
      flow(m(2026, 1), bank.id, 38000000),
      flow(m(2026, 2), bank.id, -23000000),
      flow(m(2026, 2), cash.id, 20000000),
      flow(m(2026, 3), cash.id, -2500000),
    ];

    test('suma los saldos iniciales y acumula los flujos mes a mes', () {
      final points = BalanceHistory.compute(
        accounts: [bank, cash],
        flows: flows,
        end: m(2026, 4),
        months: 4,
       converter: copConverter,
      );

      expect(points.map((p) => p.month), [m(2026, 1), m(2026, 2), m(2026, 3), m(2026, 4)]);
      expect(centsOf(points), [
        143000000, // 1.050.000 + 380.000
        140000000, // + (-230.000 + 200.000)
        137500000, // - 25.000
        137500000, // abril: sin movimientos
      ]);
    });

    test('lo ocurrido antes de la ventana cuenta en el primer punto', () {
      final points = BalanceHistory.compute(
        accounts: [bank, cash],
        flows: flows,
        end: m(2026, 3),
        months: 2,
       converter: copConverter,
      );

      // La ventana es feb-mar, pero enero ya había sumado 380.000.
      expect(points.map((p) => p.month), [m(2026, 2), m(2026, 3)]);
      expect(centsOf(points), [140000000, 137500000]);
    });

    test('lo que ocurre después del mes final no entra', () {
      final points = BalanceHistory.compute(
        accounts: [bank, cash],
        flows: flows,
        end: m(2026, 2),
        months: 2,
       converter: copConverter,
      );

      expect(centsOf(points), [143000000, 140000000]); // sin los -25.000 de marzo
    });

    test('una transferencia entre cuentas activas no cambia el total', () {
      final points = BalanceHistory.compute(
        accounts: [bank, cash],
        flows: [
          flow(m(2026, 2), bank.id, -20000000),
          flow(m(2026, 2), cash.id, 20000000),
        ],
        end: m(2026, 2),
        months: 2,
       converter: copConverter,
      );

      expect(centsOf(points), [105000000, 105000000]);
    });

    test('una transferencia a una cuenta archivada baja el total', () {
      final archived = testAccount('Vieja', balance: 777, archived: true);
      final points = BalanceHistory.compute(
        accounts: [bank, cash, archived],
        flows: [
          flow(m(2026, 2), bank.id, -20000000),
          flow(m(2026, 2), archived.id, 20000000),
        ],
        end: m(2026, 2),
        months: 2,
       converter: copConverter,
      );

      // Igual que el panel: las archivadas no cuentan, ni su saldo inicial.
      expect(centsOf(points), [105000000, 85000000]);
    });

    test('las tarjetas no cuentan: gastar con ellas no baja el total, pagarlas sí', () {
      final visa = testAccount('Visa', balance: -100000, type: AccountType.card);
      final points = BalanceHistory.compute(
        accounts: [bank, cash, visa],
        flows: [
          // Enero: una compra de 30.000 con la tarjeta.
          flow(m(2026, 1), visa.id, -3000000),
          // Febrero: se paga la tarjeta con 130.000 del banco.
          flow(m(2026, 2), bank.id, -13000000),
          flow(m(2026, 2), visa.id, 13000000),
        ],
        end: m(2026, 2),
        months: 2,
        converter: copConverter,
      );

      // Igual que el panel: el saldo de la tarjeta no entra, ni el inicial.
      // Enero no cambia; en febrero salen del banco los 130.000.
      expect(centsOf(points), [105000000, 92000000]);
    });

    test('ignora otras monedas y cuentas que no conoce', () {
      final usd = Account(
        id: 'usd',
        name: 'Dólares',
        type: bank.type,
        currency: 'USD',
        initialBalance: 500,
        currentBalance: 500,
        isArchived: false,
      );
      final points = BalanceHistory.compute(
        accounts: [bank, usd],
        flows: [
          flow(m(2026, 1), usd.id, 99900, currency: 'USD'),
          flow(m(2026, 1), 'fantasma', 5555555),
          flow(m(2026, 1), bank.id, 10000),
        ],
        end: m(2026, 1),
        months: 1,
       converter: copConverter,
      );

      expect(centsOf(points), [100010000]);
    });

    test('sin cuentas, todo en cero', () {
      final points = BalanceHistory.compute(accounts: [], flows: [], end: m(2026, 5), converter: copConverter);

      expect(points, hasLength(6));
      expect(centsOf(points).toSet(), {0});
    });

    test('cruza el cambio de año', () {
      final points = BalanceHistory.compute(
        accounts: [bank],
        flows: [flow(m(2025, 12), bank.id, 5000)],
        end: m(2026, 2),
        months: 4,
       converter: copConverter,
      );

      expect(points.map((p) => p.month), [m(2025, 11), m(2025, 12), m(2026, 1), m(2026, 2)]);
      expect(centsOf(points), [100000000, 100005000, 100005000, 100005000]);
    });

    test('suma en centavos enteros, sin error de punto flotante', () {
      final a = testAccount('A', balance: 0.1);
      final b = testAccount('B', balance: 0.2);

      final points = BalanceHistory.compute(
        accounts: [a, b],
        flows: [],
        end: m(2026, 1),
        months: 1,
       converter: copConverter,
      );

      expect(points.single.cents, 30);
    });
  });

  group('coincide con el total del panel', () {
    test('el último punto es la suma de los saldos de las cuentas activas', () async {
      final now = DateTime.now();
      DateTime d(int monthsBack, int day) => DateTime(now.year, now.month - monthsBack, day);

      final backend = FakeBackend(
        accounts: [
          testAccount('Banco', balance: 1000000),
          testAccount('Efectivo', balance: 50000),
          testAccount('Vieja', balance: 12345, archived: true),
        ],
        transactions: [
          testTransaction('1', type: TransactionType.income, accountId: 'id-Banco', amount: 500000, date: d(4, 3)),
          testTransaction('2', type: TransactionType.expense, accountId: 'id-Banco', amount: 120000.5, date: d(3, 20)),
          testTransaction('3', type: TransactionType.transfer, accountId: 'id-Banco', destinationAccountId: 'id-Efectivo', amount: 200000, date: d(2, 1)),
          testTransaction('4', type: TransactionType.transfer, accountId: 'id-Banco', destinationAccountId: 'id-Vieja', amount: 75000, date: d(1, 9)),
          testTransaction('5', type: TransactionType.expense, accountId: 'id-Efectivo', amount: 25000, date: d(0, 1)),
        ],
      );

      final accounts = await backend.accounts.fetchAll();
      final flows = await backend.summary.fetchAccountFlows();
      final active = accounts.where((a) => !a.isArchived);

      final points = BalanceHistory.compute(accounts: accounts, flows: flows, end: now, converter: copConverter);

      expect(
        points.last.cents,
        AccountTotals.centsByCurrency(active)['COP'],
        reason: 'el gráfico y el panel deben dar el mismo dinero total',
      );
    });
  });

  group('LineAxis', () {
    test('se ajusta al rango: una línea no tiene que partir de cero', () {
      final axis = LineAxis.forValues(4400000, 4550000);

      expect(axis.min, 4350000);
      expect(axis.max, 4600000);
      expect(axis.step, 50000);
    });

    test('si todo es positivo, nunca baja de cero', () {
      final axis = LineAxis.forValues(100, 900);

      expect(axis.min, 0);
      expect(axis.max, greaterThanOrEqualTo(900));
    });

    test('con valores negativos el eje los abarca', () {
      final axis = LineAxis.forValues(-500000, 1000000);

      expect(axis.min, lessThanOrEqualTo(-500000));
      expect(axis.max, greaterThanOrEqualTo(1000000));
    });

    test('un solo valor repetido se rodea de aire', () {
      final axis = LineAxis.forValues(5000000, 5000000);

      expect(axis.min, lessThan(5000000));
      expect(axis.max, greaterThan(5000000));
      expect(axis.step, greaterThan(0));
    });

    test('todo en cero da un eje utilizable', () {
      final axis = LineAxis.forValues(0, 0);

      expect(axis.min, 0);
      expect(axis.max, greaterThan(0));
    });

    test('abarca los valores y tiene pocas marcas, sea cual sea la escala', () {
      const ranges = [
        (1.0, 9.0),
        (-3.0, 4.0),
        (4400000.0, 4550000.0),
        (0.0, 1000000000.0),
        (1200000000.0, 1250000000.0),
        (-9000000.0, -1000.0),
      ];
      for (final (low, high) in ranges) {
        final axis = LineAxis.forValues(low, high);

        expect(axis.min, lessThanOrEqualTo(low), reason: '$low–$high');
        expect(axis.max, greaterThanOrEqualTo(high), reason: '$low–$high');
        expect((axis.max - axis.min) / axis.step, lessThanOrEqualTo(6), reason: '$low–$high');
      }
    });
  });
}
