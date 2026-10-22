import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/date_format.dart';
import 'package:mi_plata/core/format/money_format.dart';
import 'package:mi_plata/features/accounts/domain/account_totals.dart';

import '../support/fake_account_repository.dart';
import '../support/test_app.dart';

String normalized(String text) => text.replaceAll(' ', ' ');

void main() {
  setUpAll(initDates);

  group('formatDay', () {
    final today = DateTime(2026, 10, 22); // jueves

    test('hoy y ayer', () {
      expect(formatDay(DateTime(2026, 10, 22), today: today), 'Hoy');
      expect(formatDay(DateTime(2026, 10, 21), today: today), 'Ayer');
    });

    test('un día de este año va con el día de la semana', () {
      expect(
        formatDay(DateTime(2026, 10, 12), today: today),
        'Lunes 12 de octubre',
      );
    });

    test('un día de otro año lleva el año', () {
      expect(
        formatDay(DateTime(2025, 12, 31), today: today),
        '31 de diciembre de 2025',
      );
    });

    test('ignora la hora del día', () {
      expect(
        formatDay(DateTime(2026, 10, 22, 23, 59), today: DateTime(2026, 10, 22, 0, 1)),
        'Hoy',
      );
    });

    test('ayer sigue siendo ayer al cruzar un cambio de mes', () {
      expect(
        formatDay(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1)),
        'Ayer',
      );
    });
  });

  test('formatFullDate escribe la fecha en español', () {
    expect(formatFullDate(DateTime(2026, 3, 5)), '5 de marzo de 2026');
  });

  test('formatMonth y formatMonthShort', () {
    expect(formatMonth(DateTime(2026, 10)), 'Octubre 2026');
    expect(formatMonth(DateTime(2027, 1, 20)), 'Enero 2027');
    expect(formatMonthShort(DateTime(2026, 10)), 'oct');
    expect(formatMonthShort(DateTime(2026, 9)), isNot(contains('.')));
  });

  group('formatCompactMoney', () {
    test('abrevia miles y millones para los ejes', () {
      expect(normalized(formatCompactMoney(0)), r'$0');
      expect(normalized(formatCompactMoney(500000)), r'$500 mil');
      expect(normalized(formatCompactMoney(1500000)), r'$1,5 M');
      expect(normalized(formatCompactMoney(4000000)), r'$4 M');
    });
  });

  group('formatMoney', () {
    test('el símbolo va antes y el punto separa miles', () {
      expect(normalized(formatMoney(1500000)), r'$1.500.000');
      expect(normalized(formatMoney(-350000)), r'-$350.000');
    });

    test('los centavos solo aparecen si existen', () {
      expect(normalized(formatMoney(1250000.5)), r'$1.250.000,50');
      expect(normalized(formatMoney(0.1 + 0.2)), r'$0,30');
    });

    test('el ruido del punto flotante no genera centavos', () {
      expect(normalized(formatMoney(1500000.0000000002)), r'$1.500.000');
    });

    test('otra moneda lleva su código', () {
      expect(normalized(formatMoney(1500, currency: 'USD')), 'USD 1.500');
    });
  });

  group('AccountTotals', () {
    test('suma por moneda y las deudas restan', () {
      final totals = AccountTotals.centsByCurrency([
        testAccount('A', balance: 1500000),
        testAccount('B', balance: -350000.25),
      ]);

      expect(totals, {'COP': 114999975});
    });

    test('suma centavos sin error de punto flotante', () {
      final totals = AccountTotals.centsByCurrency([
        testAccount('A', balance: 0.1),
        testAccount('B', balance: 0.2),
      ]);

      expect(totals['COP'], 30);
    });

    test('sin cuentas no hay totales', () {
      expect(AccountTotals.centsByCurrency(const []), isEmpty);
    });
  });
}
