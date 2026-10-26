import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:mi_plata/features/recurring/domain/recurring_draft.dart';
import 'package:mi_plata/features/recurring/domain/recurring_payment.dart';
import 'package:mi_plata/features/recurring/domain/recurring_validators.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_error_message.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_ui.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

final today = DateTime(2026, 10, 23);

RecurringPayment payment({
  String name = 'Netflix',
  Recurrence recurrence = Recurrence.monthly,
  DateTime? next,
  bool noNext = false,
  int anchor = 5,
  DateTime? end,
  bool paused = false,
}) => RecurringPayment(
  id: 'rec-$name',
  name: name,
  amount: 30000,
  accountId: 'a1',
  recurrence: recurrence,
  nextDueDate: noNext ? null : (next ?? DateTime(2026, 11, 5)),
  anchorDay: anchor,
  endDate: end,
  isPaused: paused,
);

DateTime inDays(int days) => DateTime(2026, 10, 23 + days);

late AppLocalizations es;
late AppLocalizations en;

void main() {
  setUpAll(() async {
    await initDates();
    es = await loadL10n('es');
    en = await loadL10n('en');
  });

  group('Recurrence.advance', () {
    DateTime next(Recurrence r, DateTime from, int anchor) =>
        r.advance(from, anchorDay: anchor);

    test('semanas: de 7 en 7 días, y cruza el cambio de mes y de año', () {
      expect(next(Recurrence.weekly, DateTime(2026, 10, 23), 23), DateTime(2026, 10, 30));
      expect(next(Recurrence.weekly, DateTime(2026, 12, 28), 28), DateTime(2027, 1, 4));
      expect(next(Recurrence.biweekly, DateTime(2026, 10, 23), 23), DateTime(2026, 11, 6));
    });

    test('meses: el mismo día del mes siguiente', () {
      expect(next(Recurrence.monthly, DateTime(2026, 10, 15), 15), DateTime(2026, 11, 15));
      expect(next(Recurrence.monthly, DateTime(2026, 12, 15), 15), DateTime(2027, 1, 15));
    });

    test('un pago del 31 cae el último día de cada mes y vuelve al 31', () {
      var date = DateTime(2026, 1, 31);
      final seen = <DateTime>[];
      for (var i = 0; i < 5; i++) {
        date = next(Recurrence.monthly, date, 31);
        seen.add(date);
      }
      expect(seen, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
        DateTime(2026, 6, 30),
      ]);
    });

    test('en año bisiesto, febrero llega al 29', () {
      expect(next(Recurrence.monthly, DateTime(2028, 1, 31), 31), DateTime(2028, 2, 29));
    });

    test('cada 2, 3 y 6 meses', () {
      expect(next(Recurrence.bimonthly, DateTime(2026, 11, 30), 30), DateTime(2027, 1, 30));
      expect(next(Recurrence.quarterly, DateTime(2026, 11, 30), 30), DateTime(2027, 2, 28));
      expect(next(Recurrence.semiannual, DateTime(2026, 8, 31), 31), DateTime(2027, 2, 28));
    });

    test('años: el mismo día; un 29 de febrero cae el 28', () {
      expect(next(Recurrence.yearly, DateTime(2026, 3, 10), 10), DateTime(2027, 3, 10));
      expect(next(Recurrence.yearly, DateTime(2028, 2, 29), 29), DateTime(2029, 2, 28));
      expect(next(Recurrence.yearly, DateTime(2029, 2, 28), 29), DateTime(2030, 2, 28));
    });

    test('dos recurrencias iguales son iguales', () {
      expect(const Recurrence(2, RecurrenceUnit.week), Recurrence.biweekly);
      final monthly = Recurrence(1, RecurrenceUnit.values[1]);
      expect(monthly, Recurrence.monthly);
      expect(monthly.hashCode, Recurrence.monthly.hashCode);
      expect(Recurrence.monthly == Recurrence.yearly, isFalse);
    });

    test('todas las que ofrece la app son distintas', () {
      expect(Recurrence.presets.toSet(), hasLength(Recurrence.presets.length));
    });
  });

  group('RecurrenceUnit', () {
    test('se guarda con el nombre de la base de datos', () {
      for (final unit in ['week', 'month', 'year']) {
        expect(RecurrenceUnit.fromDb(unit).dbValue, unit);
      }
      expect(() => RecurrenceUnit.fromDb('day'), throwsStateError);
    });
  });

  group('RecurringPayment.fromJson', () {
    test('lee una fila de recurring_payments', () {
      final parsed = RecurringPayment.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'name': 'Arriendo',
        'amount': 1500000.5,
        'account_id': 'a1',
        'category_id': 'c1',
        'every': 1,
        'unit': 'month',
        'next_due_date': '2026-11-05',
        'anchor_day': 5,
        'end_date': '2027-12-05',
        'is_paused': false,
        'created_at': '2026-10-23T10:00:00Z',
      });

      expect(parsed.name, 'Arriendo');
      expect(parsed.amount, 1500000.5);
      expect(parsed.categoryId, 'c1');
      expect(parsed.recurrence, Recurrence.monthly);
      expect(parsed.nextDueDate, DateTime(2026, 11, 5));
      expect(parsed.anchorDay, 5);
      expect(parsed.endDate, DateTime(2027, 12, 5));
      expect(parsed.isPaused, isFalse);
      expect(parsed.isFinished, isFalse);
    });

    test('sin próxima fecha, terminó', () {
      final parsed = RecurringPayment.fromJson({
        'id': 'r1',
        'name': 'Gimnasio',
        'amount': 80000,
        'account_id': 'a1',
        'category_id': null,
        'every': 2,
        'unit': 'week',
        'next_due_date': null,
        'anchor_day': 1,
        'end_date': '2026-09-01',
        'is_paused': true,
      });

      expect(parsed.isFinished, isTrue);
      expect(parsed.canPay, isFalse);
      expect(parsed.categoryId, isNull);
      expect(parsed.recurrence, Recurrence.biweekly);
    });
  });

  group('el estado de un pago', () {
    RecurringStatus status(RecurringPayment p) => p.statusOn(today);

    test('vencido: la fecha ya pasó', () {
      final p = payment(next: inDays(-3));
      expect(status(p), RecurringStatus.overdue);
      expect(p.daysUntilDue(today), -3);
      expect(p.needsAttention(today), isTrue);
    });

    test('hoy', () {
      expect(status(payment(next: today)), RecurringStatus.today);
      expect(payment(next: today).daysUntilDue(today), 0);
    });

    test('pago próximo: dentro de los siguientes siete días', () {
      expect(status(payment(next: inDays(1))), RecurringStatus.soon);
      expect(status(payment(next: inDays(7))), RecurringStatus.soon);
      expect(payment(next: inDays(7)).needsAttention(today), isTrue);
    });

    test('todavía falta: más de siete días', () {
      final p = payment(next: inDays(8));
      expect(status(p), RecurringStatus.later);
      expect(p.needsAttention(today), isFalse);
    });

    test('la hora del día no cambia nada', () {
      final p = payment(next: DateTime(2026, 10, 24, 23, 59));
      expect(p.daysUntilDue(DateTime(2026, 10, 23, 0, 1)), 1);
      expect(p.daysUntilDue(DateTime(2026, 10, 23, 23, 59)), 1);
    });

    test('cruza el cambio de mes', () {
      expect(payment(next: DateTime(2026, 11, 2)).daysUntilDue(DateTime(2026, 10, 30)), 3);
    });

    test('en pausa no avisa, aunque esté vencido', () {
      final p = payment(next: inDays(-10), paused: true);
      expect(status(p), RecurringStatus.paused);
      expect(p.needsAttention(today), isFalse);
    });

    test('terminado: no hay fecha ni se puede pagar', () {
      final p = payment(noNext: true, end: inDays(-30));
      expect(status(p), RecurringStatus.finished);
      expect(p.daysUntilDue(today), isNull);
      expect(p.canPay, isFalse);
      expect(p.needsAttention(today), isFalse);
    });

    test('un pago en pausa todavía se puede confirmar', () {
      expect(payment(paused: true).canPay, isTrue);
    });
  });

  group('RecurringDraft.toJson', () {
    test('manda la frecuencia, el día que se conserva y los nulos explícitos', () {
      final json = RecurringDraft(
        name: 'Arriendo',
        amount: '1500000.50',
        accountId: 'a1',
        recurrence: Recurrence.quarterly,
        nextDueDate: DateTime(2026, 12, 31, 18),
      ).toJson();

      expect(json, {
        'name': 'Arriendo',
        'amount': '1500000.50',
        'account_id': 'a1',
        'category_id': null,
        'every': 3,
        'unit': 'month',
        'next_due_date': '2026-12-31',
        'anchor_day': 31,
        'end_date': null,
      });
    });

    test('con categoría y fecha final', () {
      final json = RecurringDraft(
        name: 'Netflix',
        amount: '30000',
        accountId: 'a1',
        categoryId: 'c1',
        recurrence: Recurrence.monthly,
        nextDueDate: DateTime(2026, 11, 5),
        endDate: DateTime(2027, 5, 5),
      ).toJson();

      expect(json['category_id'], 'c1');
      expect(json['end_date'], '2027-05-05');
      expect(json.containsKey('is_paused'), isFalse); // la pausa se cambia aparte
    });
  });

  group('RecurringValidators', () {
    test('el nombre es obligatorio y tiene un máximo', () {
      expect(RecurringValidators.name(es, 'Netflix'), isNull);
      expect(RecurringValidators.name(es, '  '), 'Ponle un nombre al pago');
      expect(RecurringValidators.name(es, null), 'Ponle un nombre al pago');
      expect(RecurringValidators.name(es, 'x' * 61), 'Usa 60 caracteres o menos');
      expect(RecurringValidators.name(es, 'x' * 60), isNull);
      expect(RecurringValidators.name(en, ''), 'Give the payment a name');
    });

    test('la fecha final no puede ser antes del próximo pago', () {
      final next = DateTime(2026, 11, 5);
      expect(RecurringValidators.endDate(es, null, next), isNull);
      expect(RecurringValidators.endDate(es, DateTime(2026, 11, 5, 23), next), isNull);
      expect(RecurringValidators.endDate(es, DateTime(2027, 1, 1), next), isNull);
      expect(
        RecurringValidators.endDate(es, DateTime(2026, 11, 4), next),
        'La fecha final no puede ser anterior al próximo pago',
      );
      expect(
        RecurringValidators.endDate(en, DateTime(2026, 11, 4), next),
        'The end date cannot be before the next payment',
      );
    });
  });

  group('los textos del estado', () {
    String text(RecurringPayment p, [AppLocalizations? l10n]) =>
        recurringStatusText(l10n ?? es, p, today);

    test('en español', () {
      expect(text(payment(next: inDays(-1))), 'Vencido hace 1 día');
      expect(text(payment(next: inDays(-5))), 'Vencido hace 5 días');
      expect(text(payment(next: today)), 'Pago próximo: vence hoy');
      expect(text(payment(next: inDays(1))), 'Pago próximo: vence mañana');
      expect(text(payment(next: inDays(3))), 'Pago próximo: vence en 3 días');
      expect(text(payment(next: DateTime(2026, 11, 20))), 'Próximo pago el 20 nov');
      expect(text(payment(paused: true)), 'En pausa');
      expect(text(payment(noNext: true, end: inDays(-1))), 'Terminado');
    });

    test('en inglés', () {
      expect(text(payment(next: inDays(-1)), en), 'Overdue by 1 day');
      expect(text(payment(next: inDays(-5)), en), 'Overdue by 5 days');
      expect(text(payment(next: today), en), 'Upcoming payment: due today');
      expect(text(payment(next: inDays(1)), en), 'Upcoming payment: due tomorrow');
      expect(text(payment(next: inDays(3)), en), 'Upcoming payment: due in 3 days');
      expect(text(payment(next: DateTime(2026, 11, 20)), en), 'Next payment on Nov 20');
      expect(text(payment(paused: true), en), 'Paused');
      expect(text(payment(noNext: true, end: inDays(-1)), en), 'Finished');
    });

    test('cada estado lleva su ícono: la urgencia no se dice solo con color', () {
      final icons = {
        for (final status in RecurringStatus.values) status: recurringStatusIcon(status),
      };
      expect(icons.values.toSet().length, greaterThanOrEqualTo(5));
      expect(icons[RecurringStatus.overdue], Icons.error_outline);
      expect(icons[RecurringStatus.soon], icons[RecurringStatus.today]);
    });

    test('solo lo urgente tiene un color propio', () {
      const colors = ColorScheme.light();
      expect(recurringStatusColor(RecurringStatus.overdue, colors), colors.error);
      expect(recurringStatusColor(RecurringStatus.soon, colors), isNotNull);
      expect(recurringStatusColor(RecurringStatus.today, colors), isNotNull);
      expect(recurringStatusColor(RecurringStatus.later, colors), isNull);
      expect(recurringStatusColor(RecurringStatus.paused, colors), isNull);
      expect(recurringStatusColor(RecurringStatus.finished, colors), isNull);
    });
  });

  group('recurrenceLabel', () {
    test('en español, en singular y en plural', () {
      expect(recurrenceLabel(es, Recurrence.weekly), 'Cada semana');
      expect(recurrenceLabel(es, Recurrence.biweekly), 'Cada 2 semanas');
      expect(recurrenceLabel(es, Recurrence.monthly), 'Cada mes');
      expect(recurrenceLabel(es, Recurrence.quarterly), 'Cada 3 meses');
      expect(recurrenceLabel(es, Recurrence.yearly), 'Cada año');
      expect(recurrenceLabel(es, const Recurrence(2, RecurrenceUnit.year)), 'Cada 2 años');
    });

    test('en inglés', () {
      expect(recurrenceLabel(en, Recurrence.weekly), 'Every week');
      expect(recurrenceLabel(en, Recurrence.semiannual), 'Every 6 months');
      expect(recurrenceLabel(en, Recurrence.yearly), 'Every year');
    });
  });

  group('compareRecurring', () {
    test('lo que pide atención primero, luego lo que falta, al final pausado y terminado', () {
      final soon = payment(name: 'B', next: inDays(2));
      final overdue = payment(name: 'C', next: inDays(-4));
      final later = payment(name: 'A', next: inDays(20));
      final paused = payment(name: 'D', next: inDays(1), paused: true);
      final finished = payment(name: 'E', noNext: true, end: inDays(-2));

      final sorted = [finished, later, paused, soon, overdue]
        ..sort((a, b) => compareRecurring(a, b, today));

      expect(sorted.map((p) => p.name), ['C', 'B', 'A', 'D', 'E']);
    });

    test('con el mismo estado, la fecha más cercana; luego el nombre', () {
      final a = payment(name: 'Zeta', next: inDays(3));
      final b = payment(name: 'Beta', next: inDays(3));
      final c = payment(name: 'Alfa', next: inDays(5));

      final sorted = [a, c, b]..sort((x, y) => compareRecurring(x, y, today));

      expect(sorted.map((p) => p.name), ['Beta', 'Zeta', 'Alfa']);
    });
  });

  group('recurringErrorMessage', () {
    PostgrestException failure(String message, {String? code, Object? details}) =>
        PostgrestException(message: message, code: code, details: details);

    test('traduce los códigos de nuestras reglas', () {
      expect(
        recurringErrorMessage(en, failure('x', code: '23514', details: 'recurring_finished')),
        'This recurring payment has already ended',
      );
      expect(
        recurringErrorMessage(es, failure('x', code: '23514', details: 'recurring_category_mismatch')),
        'Solo las categorías de gasto sirven en un pago recurrente',
      );
      expect(
        recurringErrorMessage(es, failure('x', code: '23514', details: 'recurring_end_before_due')),
        'La fecha final no puede ser anterior al próximo pago',
      );
    });

    test('el movimiento que crea un pago también se explica', () {
      expect(
        recurringErrorMessage(
          en,
          failure('x', code: '23514', details: 'transaction_category_mismatch'),
        ),
        'The chosen category does not match this type of transaction',
      );
    });

    test('un pago que ya no existe', () {
      expect(
        recurringErrorMessage(en, failure('x', code: '23503', details: 'recurring_not_found')),
        'The recurring payment no longer exists. Reopen the screen.',
      );
      expect(
        recurringErrorMessage(es, failure('x', code: '23503')),
        'El pago recurrente ya no existe. Vuelve a abrir la pantalla.',
      );
    });

    test('una restricción técnica da el mensaje genérico', () {
      expect(
        recurringErrorMessage(es, failure('violates check constraint "x"', code: '23514')),
        'Revisa los datos del pago: el nombre, el monto y las fechas.',
      );
    });

    test('sin código se muestra el de la base; la sesión y la red, sus mensajes', () {
      expect(recurringErrorMessage(es, failure('Mensaje antiguo', code: '23514')), 'Mensaje antiguo');
      expect(
        recurringErrorMessage(es, failure('x', code: 'PGRST301')),
        'Tu sesión expiró. Vuelve a iniciar sesión.',
      );
      expect(recurringErrorMessage(es, StateError('boom')), startsWith('No se pudo completar'));
    });
  });
}
