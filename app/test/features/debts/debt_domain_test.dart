import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/currency/domain/currency_converter.dart';
import 'package:mi_plata/features/currency/domain/exchange_rate.dart';
import 'package:mi_plata/features/debts/domain/debt.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/debts/domain/debt_draft.dart';
import 'package:mi_plata/features/debts/domain/debt_payment.dart';
import 'package:mi_plata/features/debts/domain/debt_totals.dart';
import 'package:mi_plata/features/debts/domain/debt_validators.dart';
import 'package:mi_plata/features/debts/presentation/debt_error_message.dart';
import 'package:mi_plata/features/debts/presentation/debt_ui.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

const payable = DebtDirection.payable;
const receivable = DebtDirection.receivable;

final today = DateTime(2026, 10, 22);

Debt debt({
  DebtDirection direction = payable,
  String counterparty = 'Juan',
  double amount = 500000,
  double paid = 0,
  String currency = 'COP',
  DateTime? dueDate,
  bool archived = false,
}) => Debt(
  id: 'd-$counterparty',
  direction: direction,
  counterparty: counterparty,
  amount: amount,
  paid: paid,
  remaining: amount - paid,
  currency: currency,
  startDate: DateTime(2026, 1, 1),
  dueDate: dueDate,
  isArchived: archived,
);

DateTime inDays(int days) => DateTime(2026, 10, 22 + days);

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });


  group('modelo', () {
    test('Debt.fromJson lee una fila de v_debt_balances', () {
      final parsed = Debt.fromJson({
        'id': 'd1',
        'user_id': 'u1',
        'direction': 'receivable',
        'counterparty': 'María',
        'amount': 100000.0,
        'currency': 'COP',
        'start_date': '2026-10-02',
        'due_date': '2026-12-31',
        'notes': 'Para el arriendo',
        'is_archived': false,
        'paid': 40000,
        'remaining': 60000.0,
      });

      expect(parsed.direction, receivable);
      expect(parsed.counterparty, 'María');
      expect(parsed.paid, 40000);
      expect(parsed.remaining, 60000);
      expect(parsed.startDate, DateTime(2026, 10, 2));
      expect(parsed.dueDate, DateTime(2026, 12, 31));
      expect(parsed.notes, 'Para el arriendo');
    });

    test('las fechas y notas opcionales pueden venir nulas', () {
      final parsed = Debt.fromJson({
        'id': 'd1',
        'direction': 'payable',
        'counterparty': 'Pedro',
        'amount': 1,
        'currency': 'COP',
        'start_date': '2026-10-02',
        'due_date': null,
        'notes': null,
        'is_archived': true,
        'paid': 0,
        'remaining': 1,
      });

      expect(parsed.dueDate, isNull);
      expect(parsed.notes, isNull);
      expect(parsed.isArchived, isTrue);
    });

    test('DebtDirection conoce los dos sentidos', () {
      for (final value in ['payable', 'receivable']) {
        expect(DebtDirection.fromDb(value).dbValue, value);
      }
      expect(() => DebtDirection.fromDb('otro'), throwsStateError);
    });

    test('DebtPayment.fromJson lee una fila de v_debt_payments', () {
      final payment = DebtPayment.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'debt_id': 'd1',
        'transaction_id': 't1',
        'amount': 200000,
        'transaction_date': '2026-10-15',
        'account_id': 'a1',
        'description': 'Abono a Juan',
      });

      expect(payment.transactionId, 't1');
      expect(payment.amount, 200000);
      expect(payment.date, DateTime(2026, 10, 15));
    });
  });

  group('avance', () {
    test('el progreso es lo pagado sobre el total, entre 0 y 1', () {
      expect(debt(paid: 125000).progress, 0.25);
      expect(debt().progress, 0);
      expect(debt(paid: 600000).progress, 1); // pagada de más
    });

    test('se salda cuando no queda nada, comparando en centavos', () {
      expect(debt(paid: 500000).isSettled, isTrue);
      expect(debt(paid: 499999.99).isSettled, isFalse);
      // Un resto de punto flotante no deja la deuda viva.
      expect(
        Debt(
          id: 'x',
          direction: payable,
          counterparty: 'x',
          amount: 0.3,
          paid: 0.1 + 0.2,
          remaining: 0.3 - (0.1 + 0.2),
          currency: 'COP',
          startDate: today,
          isArchived: false,
        ).isSettled,
        isTrue,
      );
    });
  });

  group('estado según el vencimiento', () {
    test('sin fecha está activa', () {
      final noDate = debt();
      expect(noDate.daysUntilDue(today), isNull);
      expect(noDate.statusOn(today), DebtStatus.active);
    });

    test('vencida: la fecha ya pasó y falta dinero', () {
      expect(debt(dueDate: inDays(-1)).statusOn(today), DebtStatus.overdue);
      expect(debt(dueDate: inDays(-30)).statusOn(today), DebtStatus.overdue);
    });

    test('por vencer: hoy y los próximos 7 días', () {
      expect(debt(dueDate: inDays(0)).statusOn(today), DebtStatus.dueSoon);
      expect(debt(dueDate: inDays(7)).statusOn(today), DebtStatus.dueSoon);
    });

    test('con 8 días o más sigue activa', () {
      expect(debt(dueDate: inDays(8)).statusOn(today), DebtStatus.active);
    });

    test('una deuda saldada es "saldada" aunque esté vencida', () {
      final settled = debt(paid: 500000, dueDate: inDays(-10));
      expect(settled.statusOn(today), DebtStatus.settled);
    });

    test('cuenta días de calendario, sin importar la hora', () {
      final due = debt(dueDate: DateTime(2026, 10, 23));
      expect(due.daysUntilDue(DateTime(2026, 10, 22, 23, 59)), 1);
      expect(due.daysUntilDue(DateTime(2026, 10, 22, 0, 1)), 1);
    });
  });

  group('textos de estado', () {
    String text(Debt d) => debtStatusText(l10n, d, today);

    test('describe cada caso en una frase', () {
      expect(text(debt()), 'Sin fecha de vencimiento');
      expect(text(debt(paid: 500000)), 'Saldada');
      expect(text(debt(dueDate: inDays(-1))), 'Vencida hace 1 día');
      expect(text(debt(dueDate: inDays(-5))), 'Vencida hace 5 días');
      expect(text(debt(dueDate: inDays(0))), 'Vence hoy');
      expect(text(debt(dueDate: inDays(1))), 'Vence mañana');
      expect(text(debt(dueDate: inDays(3))), 'Vence en 3 días');
      expect(text(debt(dueDate: inDays(7))), 'Vence en 7 días');
      expect(text(debt(dueDate: DateTime(2026, 12, 25))), 'Vence el 25 dic');
    });
  });

  group('orden de la lista', () {
    test('lo pendiente primero, lo que vence antes arriba, lo saldado al final', () {
      final list = [
        debt(counterparty: 'Saldada', paid: 500000, dueDate: inDays(-9)),
        debt(counterparty: 'SinFecha'),
        debt(counterparty: 'Lejana', dueDate: inDays(40)),
        debt(counterparty: 'Vencida', dueDate: inDays(-3)),
        debt(counterparty: 'Cercana', dueDate: inDays(2)),
      ]..sort(compareDebts);

      expect(list.map((d) => d.counterparty), [
        'Vencida',
        'Cercana',
        'Lejana',
        'SinFecha',
        'Saldada',
      ]);
    });

    test('con el mismo vencimiento, por nombre sin importar mayúsculas', () {
      final list = [
        debt(counterparty: 'ana'),
        debt(counterparty: 'Beto'),
        debt(counterparty: 'Carla'),
      ]..sort(compareDebts);

      expect(list.map((d) => d.counterparty), ['ana', 'Beto', 'Carla']);
    });
  });

  group('totales', () {
    final debts = [
      debt(counterparty: 'A', amount: 500000, paid: 200000),
      debt(counterparty: 'B', amount: 80000),
      debt(counterparty: 'C', amount: 100000, paid: 100000), // saldada
      debt(counterparty: 'D', direction: receivable, amount: 300000, paid: 50000),
      debt(counterparty: 'E', amount: 999, archived: true),
      debt(counterparty: 'F', amount: 500, currency: 'USD'),
    ];

    test('suma lo pendiente de cada sentido, sin archivadas ni saldadas', () {
      expect(DebtTotals.remaining(debts, payable, copConverter).cents, 38000000);
      expect(DebtTotals.remaining(debts, receivable, copConverter).cents, 25000000);
    });

    test('una moneda con tasa se suma ya convertida; sin tasa, se aparta', () {
      final usd = [
        debt(counterparty: 'A', amount: 100, currency: 'USD'),
        debt(counterparty: 'B', amount: 200, currency: 'EUR'),
      ];
      final converter = CurrencyConverter(
        base: 'COP',
        rates: {
          'USD': ExchangeRate(
            currency: 'USD',
            rate: 4000,
            updatedAt: DateTime(2026, 10, 1),
          ),
        },
      );

      final total = DebtTotals.remaining(usd, payable, converter);

      expect(total.cents, 40000000); // US$100 a $4.000
      expect(total.missing, {'EUR'});
      expect(total.isComplete, isFalse);
    });

    test('sin deudas es cero', () {
      expect(DebtTotals.remaining(const [], payable, copConverter).cents, 0);
    });

    test('suma en centavos sin error de punto flotante', () {
      final total = DebtTotals.remaining([
        debt(counterparty: 'X', amount: 0.1),
        debt(counterparty: 'Y', amount: 0.2),
      ], payable, copConverter);

      expect(total.cents, 30);
    });
  });

  group('validadores', () {
    test('la persona es obligatoria y tiene un máximo', () {
      expect(DebtValidators.counterparty(l10n, 'Juan'), isNull);
      expect(DebtValidators.counterparty(l10n, '  '), 'Escribe el nombre de la persona');
      expect(DebtValidators.counterparty(l10n, null), 'Escribe el nombre de la persona');
      expect(DebtValidators.counterparty(l10n, 'x' * 61), 'Usa 60 caracteres o menos');
    });

    test('las notas tienen un máximo', () {
      expect(DebtValidators.notes(l10n, null), isNull);
      expect(DebtValidators.notes(l10n, 'x' * 300), isNull);
      expect(DebtValidators.notes(l10n, 'x' * 301), 'Usa 300 caracteres o menos');
    });

    test('el monto debe ser positivo', () {
      expect(DebtValidators.amount(l10n, '500.000'), isNull);
      expect(DebtValidators.amount(l10n, '0'), 'El monto debe ser mayor que cero');
      expect(DebtValidators.amount(l10n, ''), 'Ingresa el monto');
    });

    test('el vencimiento no puede ser antes del inicio', () {
      final start = DateTime(2026, 10, 10, 15);
      expect(DebtValidators.dueDate(l10n, null, start), isNull);
      expect(DebtValidators.dueDate(l10n, DateTime(2026, 10, 10), start), isNull);
      expect(DebtValidators.dueDate(l10n, DateTime(2026, 11, 1), start), isNull);
      expect(
        DebtValidators.dueDate(l10n, DateTime(2026, 10, 9), start),
        'El vencimiento no puede ser anterior al inicio',
      );
    });

    group('abono', () {
      String? check(String? value) =>
          DebtValidators.paymentAmount(
            l10n,
            value,
            remaining: 300000,
            currency: 'COP',
          );

      test('acepta hasta lo que falta, inclusive', () {
        expect(check('100.000'), isNull);
        expect(check('300.000'), isNull);
        expect(check('300000'), isNull);
      });

      test('rechaza lo que se pasa, incluso por un centavo', () {
        const message = r'No puede superar lo pendiente ($300.000)';
        expect(check('300.001'), message);
        expect(check('300000,01'), message);
      });

      test('exige un monto válido y positivo', () {
        expect(check(''), 'Ingresa el monto');
        expect(check('0'), 'El monto debe ser mayor que cero');
        expect(check('abc'), startsWith('Monto no válido'));
      });
    });
  });

  group('parámetros de create_debt', () {
    test('convierte fechas y deja los nulos explícitos', () {
      final params = DebtDraft(
        direction: receivable,
        counterparty: 'María',
        amount: '100000.50',
        startDate: DateTime(2026, 3, 5, 18),
      ).toRpcParams();

      expect(params, {
        'p_direction': 'receivable',
        'p_counterparty': 'María',
        'p_amount': '100000.50',
        'p_start_date': '2026-03-05',
        'p_due_date': null,
        'p_notes': null,
        'p_account_id': null,
        'p_description': null,
        'p_currency': null,
      });
    });

    test('incluye el vencimiento y la cuenta cuando existen', () {
      final params = DebtDraft(
        direction: payable,
        counterparty: 'Juan',
        amount: '500000',
        startDate: DateTime(2026, 10, 1),
        dueDate: DateTime(2026, 12, 1),
        notes: 'Para el carro',
        accountId: 'cuenta-1',
        description: 'Loan from Juan',
      ).toRpcParams();

      expect(params['p_due_date'], '2026-12-01');
      expect(params['p_notes'], 'Para el carro');
      expect(params['p_account_id'], 'cuenta-1');
      expect(params['p_description'], 'Loan from Juan');
    });
  });

  group('debtErrorMessage', () {
    String message(String? code, [String text = 'x']) =>
        debtErrorMessage(l10n, PostgrestException(message: text, code: code));

    test('muestra tal cual el mensaje de la base si no trae un código', () {
      const own = 'El abono supera lo que falta por pagar';
      expect(message('23514', own), own);
    });

    test('con código, lo traduce al idioma de la app', () {
      final error = PostgrestException(
        message: 'El abono supera lo que falta por pagar',
        code: '23514',
        details: 'payment_exceeds_remaining',
      );
      expect(debtErrorMessage(l10n, error), 'El abono supera lo que falta por pagar');
    });

    test('oculta el mensaje técnico de una restricción CHECK', () {
      expect(
        message('23514', 'new row for relation "debts" violates check constraint "x"'),
        startsWith('Revisa los datos de la deuda'),
      );
    });

    test('traduce otros códigos y da un mensaje genérico para el resto', () {
      expect(message('23503'), startsWith('La cuenta o la deuda ya no existe'));
      expect(message('PGRST301'), startsWith('Tu sesión expiró'));
      expect(message('XX000'), startsWith('No se pudo completar'));
      expect(debtErrorMessage(l10n, StateError('x')), startsWith('No se pudo'));
    });
  });
}
