import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/formats.dart';
import 'package:mi_plata/features/accounts/domain/account_totals.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/currency/domain/currency.dart';
import 'package:mi_plata/features/currency/domain/currency_converter.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:mi_plata/features/currency/domain/rate_parser.dart';
import 'package:mi_plata/features/summary/domain/balance_history.dart';
import 'package:mi_plata/features/summary/domain/month_summary.dart';
import 'package:mi_plata/features/summary/domain/monthly_total.dart';
import 'package:mi_plata/features/transactions/domain/negative_balance_check.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

ExchangeRate rate(String currency, double value) => ExchangeRate(
  currency: currency,
  rate: value,
  updatedAt: DateTime(2026, 10, 1),
);

/// El peso como base, con el dólar a $4.000 y el euro a $4.400.
final converter = CurrencyConverter(
  base: 'COP',
  rates: {'USD': rate('USD', 4000), 'EUR': rate('EUR', 4400)},
);

final oct = DateTime(2026, 10);

MonthlyTotal row(
  TransactionType type,
  double total, {
  String currency = 'COP',
  String? category,
}) => MonthlyTotal(
  month: oct,
  currency: currency,
  type: type,
  categoryId: category,
  total: total,
  movements: 1,
);

late Formats es;
late Formats en;

void main() {
  setUpAll(() async {
    await initDates();
    es = await loadFormats('es');
    en = await loadFormats('en');
  });

  group('las monedas', () {
    test('el símbolo de cada una; el peso y el dólar no se confunden', () {
      expect(currencySymbol('COP'), r'$');
      expect(currencySymbol('USD'), r'US$');
      expect(currencySymbol('EUR'), '€');
      expect(currencySymbol('GBP'), '£');
    });

    test('una moneda que no está en la lista se muestra con su código', () {
      expect(currencySymbol('XYZ'), 'XYZ ');
    });

    test('todas las de la lista tienen un código de tres letras distinto', () {
      final codes = supportedCurrencies.map((c) => c.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes.every((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)), isTrue);
      expect(codes, contains(defaultCurrency));
    });
  });

  group('ExchangeRate.fromJson', () {
    test('lee una fila de exchange_rates', () {
      final parsed = ExchangeRate.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'currency': 'USD',
        'rate': 4012.5,
        'updated_at': '2026-10-20T15:30:00Z',
      });

      expect(parsed.currency, 'USD');
      expect(parsed.rate, 4012.5);
      expect(parsed.updatedAt.toUtc(), DateTime.utc(2026, 10, 20, 15, 30));
    });

    test('un entero también sirve', () {
      expect(
        ExchangeRate.fromJson({
          'currency': 'EUR',
          'rate': 4400,
          'updated_at': '2026-10-20T00:00:00Z',
        }).rate,
        4400,
      );
    });
  });

  group('CurrencyConverter', () {
    test('la moneda base vale uno y siempre se puede convertir', () {
      expect(converter.canConvert('COP'), isTrue);
      expect(converter.rateOf('COP'), 1);
      expect(converter.toBaseCents(123456, 'COP'), 123456);
    });

    test('pasa a la base con la tasa y redondea al centavo', () {
      // US$ 100,50 a $4.000 = $402.000.
      expect(converter.toBaseCents(10050, 'USD'), 40200000);
      // €0,01 a $4.400 = $44.
      expect(converter.toBaseCents(1, 'EUR'), 4400);
      expect(CurrencyConverter(
        base: 'COP',
        rates: {'USD': rate('USD', 4012.345)},
      ).toBaseCents(333, 'USD'), 1336111); // 333 * 4012,345 = 1.336.110,885
    });

    test('un negativo se convierte igual', () {
      expect(converter.toBaseCents(-10000, 'USD'), -40000000);
    });

    test('una moneda sin tasa no se convierte: devuelve null', () {
      expect(converter.canConvert('MXN'), isFalse);
      expect(converter.rateOf('MXN'), isNull);
      expect(converter.toBaseCents(10000, 'MXN'), isNull);
    });

    test('dice cuáles de un grupo de monedas no tienen tasa', () {
      expect(converter.missing(['COP', 'USD', 'MXN', 'MXN', 'ARS']), {'MXN', 'ARS'});
      expect(converter.missing(['COP', 'USD']), isEmpty);
    });

    test('con otra base, todo cambia de referencia', () {
      final usdBase = CurrencyConverter(
        base: 'USD',
        rates: {'COP': rate('COP', 0.00025)},
      );
      expect(usdBase.toBaseCents(40000000, 'COP'), 10000); // $400.000 = US$100
      expect(usdBase.canConvert('USD'), isTrue);
      expect(usdBase.canConvert('EUR'), isFalse);
    });

    test('la tasa que dejan los dos montos de una transferencia', () {
      expect(
        CurrencyConverter.impliedRate(fromCents: 100, toCents: 401250),
        4012.5,
      );
      expect(CurrencyConverter.impliedRate(fromCents: 0, toCents: 100), isNull);
      expect(CurrencyConverter.impliedRate(fromCents: 100, toCents: -5), isNull);
    });
  });

  group('RateParser', () {
    test('lee una tasa en el formato del idioma', () {
      expect(RateParser.parse('4.012,5', es), '4012.5');
      expect(RateParser.parse('4,012.5', en), '4012.5');
      expect(RateParser.parse('4000', es), '4000');
    });

    test('admite hasta seis decimales (una moneda fuerte contra una débil)', () {
      expect(RateParser.parse('0,00025', es), '0.00025');
      expect(RateParser.parse('0.000250', en), '0.000250');
      expect(RateParser.parse('0,0000001', es), isNull); // siete decimales
    });

    test('rechaza lo vacío, cero, negativo y lo mal escrito', () {
      for (final input in [null, '', '   ', '0', '0,0', '-4', 'abc', '4.0', '1,2,3']) {
        expect(RateParser.parse(input, es), isNull, reason: 'entrada "$input"');
      }
    });

    test('respeta los diez dígitos enteros de numeric(20, 10)', () {
      expect(RateParser.parse('9999999999', es), '9999999999');
      expect(RateParser.parse('10000000000', es), isNull);
    });

    test('lo que muestra se puede volver a leer, sin ceros de sobra', () {
      expect(RateParser.toInput(4012.5, es), '4012,5');
      expect(RateParser.toInput(4000, es), '4000');
      expect(RateParser.toInput(0.00025, es), '0,00025');
      expect(RateParser.toInput(4012.5, en), '4012.5');
      for (final value in [4000.0, 4012.5, 0.00025, 3.141593]) {
        final text = RateParser.toInput(value, es);
        expect(double.parse(RateParser.parse(text, es)!), value);
      }
    });
  });

  group('Formats.rate', () {
    test('escribe la tasa según el idioma, con hasta seis decimales', () {
      expect(es.rate(4012.5), '4.012,5');
      expect(en.rate(4012.5), '4,012.5');
      expect(es.rate(0.00025), '0,00025');
      expect(en.rate(4000), '4,000');
    });
  });

  group('AccountTotals.inBase', () {
    test('suma todo en la moneda base con las tasas', () {
      final accounts = [
        testAccount('Banco', balance: 1000000),
        testAccount('Dólares', balance: 100, currency: 'USD'),
        testAccount('Euros', balance: 50, currency: 'EUR'),
      ];

      final total = AccountTotals.inBase(accounts, converter);

      // 1.000.000 + 100 * 4.000 + 50 * 4.400 = 1.620.000
      expect(total.cents, 162000000);
      expect(total.isComplete, isTrue);
    });

    test('una moneda sin tasa no se suma y se avisa', () {
      final accounts = [
        testAccount('Banco', balance: 1000000),
        testAccount('Pesos mexicanos', balance: 500, currency: 'MXN'),
      ];

      final total = AccountTotals.inBase(accounts, converter);

      expect(total.cents, 100000000);
      expect(total.missing, {'MXN'});
      expect(total.isComplete, isFalse);
    });

    test('un saldo negativo (sobregiro) resta', () {
      final accounts = [
        testAccount('Banco', balance: 1000000),
        testAccount('Banco en dólares', balance: -50, currency: 'USD'),
      ];

      expect(AccountTotals.inBase(accounts, converter).cents, 80000000);
    });

    test('las tarjetas no cuentan: ese dinero sigue en las cuentas', () {
      final accounts = [
        testAccount('Banco', balance: 1000000),
        testAccount('Visa', balance: -300000, type: AccountType.card),
        testAccount('Tarjeta en dólares', balance: -50, currency: 'USD', type: AccountType.card),
      ];

      expect(AccountTotals.inBase(accounts, converter).cents, 100000000);
      expect(AccountTotals.centsByCurrency(accounts), {'COP': 100000000});
    });

    test('lo que se debe en las tarjetas se suma aparte, por moneda y por tarjeta', () {
      final accounts = [
        testAccount('Banco', balance: -999),
        testAccount('Visa', balance: -300000, type: AccountType.card),
        testAccount('Mastercard', balance: -100000.5, type: AccountType.card),
        // El saldo a favor de una tarjeta no paga la deuda de otra.
        testAccount('Amex', balance: 80000, type: AccountType.card),
        testAccount('Dólares', balance: -50, currency: 'USD', type: AccountType.card),
        testAccount('Sin deuda', type: AccountType.card),
      ];

      expect(
        AccountTotals.cardDebtCentsByCurrency(accounts),
        {'COP': 40000050, 'USD': 5000},
      );
      // 400.000,50 + 50 * 4.000 = 600.000,50
      expect(AccountTotals.cardDebtInBase(accounts, converter).cents, 60000050);
    });

    test('la deuda de una tarjeta en una moneda sin tasa se avisa', () {
      final accounts = [
        testAccount('Visa', balance: -100000, type: AccountType.card),
        testAccount('Pesos mexicanos', balance: -500, currency: 'MXN', type: AccountType.card),
      ];

      final debt = AccountTotals.cardDebtInBase(accounts, converter);
      expect(debt.cents, 10000000);
      expect(debt.missing, {'MXN'});
    });

    test('sin tarjetas no hay deuda', () {
      expect(
        AccountTotals.cardDebtCentsByCurrency([testAccount('Banco', balance: -5)]),
        isEmpty,
      );
      expect(AccountTotals.cardDebtInBase(const [], converter).cents, 0);
    });

    test('sin cuentas es cero', () {
      expect(AccountTotals.inBase(const [], converter).cents, 0);
    });

    test('suma por moneda sin convertir', () {
      final totals = AccountTotals.centsByCurrency([
        testAccount('A', balance: 10),
        testAccount('B', balance: 20, currency: 'USD'),
        testAccount('C', balance: 5, currency: 'USD'),
      ]);
      expect(totals, {'COP': 1000, 'USD': 2500});
    });
  });

  group('SummaryCalculator con varias monedas', () {
    test('los movimientos de otra moneda se pasan a la base', () {
      final summary = SummaryCalculator.forMonth(
        [
          row(TransactionType.expense, 100000, category: 'a'),
          row(TransactionType.expense, 10, currency: 'USD', category: 'a'),
          row(TransactionType.income, 2, currency: 'EUR'),
        ],
        oct,
        converter,
      );

      // Gasto: 100.000 + 10 * 4.000; ingreso: 2 * 4.400.
      expect(summary.expenseCents, 14000000);
      expect(summary.incomeCents, 880000);
      expect(summary.expenseCentsByCategory['a'], 14000000);
      expect(summary.currency, 'COP');
      expect(summary.missingCurrencies, isEmpty);
      expect(summary.movements, 3);
    });

    test('una moneda sin tasa se aparta, no se mezcla', () {
      final summary = SummaryCalculator.forMonth(
        [
          row(TransactionType.expense, 100000),
          row(TransactionType.expense, 5000, currency: 'MXN'),
        ],
        oct,
        converter,
      );

      expect(summary.expenseCents, 10000000);
      expect(summary.missingCurrencies, {'MXN'});
      expect(summary.movements, 1);
    });

    test('con otra base, el resumen está en esa moneda', () {
      final usdBase = CurrencyConverter(
        base: 'USD',
        rates: {'COP': rate('COP', 0.00025)},
      );
      final summary = SummaryCalculator.forMonth(
        [row(TransactionType.expense, 400000)],
        oct,
        usdBase,
      );

      expect(summary.currency, 'USD');
      expect(summary.expenseCents, 10000); // US$100
    });

    test('la tendencia convierte cada mes', () {
      final points = SummaryCalculator.trend(
        [
          row(TransactionType.expense, 10, currency: 'USD'),
          MonthlyTotal(
            month: DateTime(2026, 9),
            currency: 'COP',
            type: TransactionType.expense,
            categoryId: null,
            total: 500,
            movements: 1,
          ),
        ],
        oct,
        converter,
        months: 2,
      );

      expect(points.map((p) => p.expenseCents), [50000, 4000000]);
    });

    test('las monedas sin tasa de cualquier mes de las filas', () {
      expect(
        SummaryCalculator.missingCurrencies([
          row(TransactionType.expense, 1),
          row(TransactionType.income, 1, currency: 'ARS'),
        ], converter),
        {'ARS'},
      );
    });
  });

  group('BalanceHistory con varias monedas', () {
    final bank = testAccount('Banco', balance: 1000000);
    final dollars = testAccount('Dólares', balance: 100, currency: 'USD');
    final mxn = testAccount('Pesos mexicanos', balance: 500, currency: 'MXN');

    AccountFlow flow(String account, DateTime month, int cents, String currency) =>
        AccountFlow(
          month: month,
          accountId: account,
          currency: currency,
          cents: cents,
        );

    test('cada moneda se reconstruye aparte y se pasa a la base', () {
      final points = BalanceHistory.compute(
        accounts: [bank, dollars],
        flows: [
          flow(bank.id, DateTime(2026, 9), -10000, 'COP'),
          flow(dollars.id, DateTime(2026, 10), 5000, 'USD'), // +US$50
        ],
        end: oct,
        converter: converter,
        months: 2,
      );

      // Septiembre: 1.000.000 - 100 + US$100 * 4.000 = 1.399.900
      // Octubre: lo mismo + US$50 * 4.000 más = 1.599.900
      expect(points.map((p) => p.cents), [139990000, 159990000]);
    });

    test('una moneda sin tasa no entra al total y se avisa', () {
      final points = BalanceHistory.compute(
        accounts: [bank, mxn],
        flows: const [],
        end: oct,
        converter: converter,
        months: 1,
      );

      expect(points.single.cents, 100000000);
      expect(BalanceHistory.missingCurrencies([bank, mxn], converter), {'MXN'});
      expect(BalanceHistory.missingCurrencies([bank, dollars], converter), isEmpty);
    });

    test('las cuentas archivadas no cuentan', () {
      final points = BalanceHistory.compute(
        accounts: [bank, testAccount('Vieja', balance: 99, currency: 'USD', archived: true)],
        flows: const [],
        end: oct,
        converter: converter,
        months: 1,
      );
      expect(points.single.cents, 100000000);
    });
  });

  group('el aviso de saldo negativo en una transferencia entre monedas', () {
    final pesos = testAccount('Pesos', balance: 500000, type: AccountType.bank);
    final usd = testAccount('Dólares', balance: 10, currency: 'USD');

    NegativeBalance? only(List<NegativeBalance> list) => list.isEmpty ? null : list.single;

    test('al destino le suma lo que llega, no lo que sale', () {
      // Salen $400.000 de Pesos y llegan US$99,50 a Dólares: nadie queda en negativo.
      final result = NegativeBalanceCheck.after(
        accounts: [pesos, usd],
        draft: TransactionDraft(
          type: TransactionType.transfer,
          accountId: pesos.id,
          destinationAccountId: usd.id,
          amount: '400000',
          destinationAmount: '99.50',
          date: DateTime(2026, 10, 22),
        ),
      );
      expect(result, isEmpty);
    });

    test('avisa si el origen no alcanza, en su propia moneda', () {
      final result = NegativeBalanceCheck.after(
        accounts: [pesos, usd],
        draft: TransactionDraft(
          type: TransactionType.transfer,
          accountId: pesos.id,
          destinationAccountId: usd.id,
          amount: '600000',
          destinationAmount: '150',
          date: DateTime(2026, 10, 22),
        ),
      );
      expect(only(result)?.account.name, 'Pesos');
      expect(only(result)?.balance, -100000);
    });

    test('desde dólares hacia pesos: avisa si los dólares no alcanzan', () {
      final result = NegativeBalanceCheck.after(
        accounts: [pesos, usd],
        draft: TransactionDraft(
          type: TransactionType.transfer,
          accountId: usd.id,
          destinationAccountId: pesos.id,
          amount: '25',
          destinationAmount: '100000',
          date: DateTime(2026, 10, 22),
        ),
      );
      expect(only(result)?.account.name, 'Dólares');
      expect(only(result)?.balance, -15);
    });

    test('borrar una transferencia devuelve al destino lo que le había llegado', () {
      final previous = testTransaction(
        't1',
        type: TransactionType.transfer,
        accountId: pesos.id,
        destinationAccountId: usd.id,
        amount: 400000,
        destinationAmount: 99.5,
        date: DateTime(2026, 10, 1),
      );

      // Dólares tiene 10 (ya incluye los 99,50 que llegaron: se simula con 109,50).
      final withTransfer = testAccount('Dólares', balance: 109.5, currency: 'USD');
      final result = NegativeBalanceCheck.after(
        accounts: [pesos, withTransfer],
        previous: previous,
      );

      // Quitar los 99,50 que llegaron deja 10 en dólares: sin aviso.
      expect(result, isEmpty);

      // Pero si ya se gastó todo, quitar lo que llegó sí deja en negativo.
      final spent = testAccount('Dólares', balance: 50, currency: 'USD');
      final warning = NegativeBalanceCheck.after(accounts: [pesos, spent], previous: previous);
      expect(only(warning)?.account.name, 'Dólares');
      expect(only(warning)?.balance, -49.5);
    });
  });
}
