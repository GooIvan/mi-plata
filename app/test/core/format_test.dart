import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/formats.dart';
import 'package:mi_plata/features/accounts/domain/account_totals.dart';
import 'package:mi_plata/l10n/l10n.dart';

import '../support/fake_account_repository.dart';
import '../support/test_app.dart';

String normalized(String text) => text.replaceAll(' ', ' ');

late AppLocalizations l10n;
late Formats formats;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    formats = Formats(l10n);
    await initDates();
  });


  group('formatDay', () {
    final today = DateTime(2026, 10, 22); // jueves

    test('hoy y ayer', () {
      expect(formats.day(DateTime(2026, 10, 22), today: today), 'Hoy');
      expect(formats.day(DateTime(2026, 10, 21), today: today), 'Ayer');
    });

    test('un día de este año va con el día de la semana', () {
      expect(
        formats.day(DateTime(2026, 10, 12), today: today),
        'Lunes 12 de octubre',
      );
    });

    test('un día de otro año lleva el año', () {
      expect(
        formats.day(DateTime(2025, 12, 31), today: today),
        '31 de diciembre de 2025',
      );
    });

    test('ignora la hora del día', () {
      expect(
        formats.day(DateTime(2026, 10, 22, 23, 59), today: DateTime(2026, 10, 22, 0, 1)),
        'Hoy',
      );
    });

    test('ayer sigue siendo ayer al cruzar un cambio de mes', () {
      expect(
        formats.day(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1)),
        'Ayer',
      );
    });
  });

  test('formatFullDate escribe la fecha en español', () {
    expect(formats.fullDate(DateTime(2026, 3, 5)), '5 de marzo de 2026');
  });

  test('formatMonth y formatMonthShort', () {
    expect(formats.month(DateTime(2026, 10)), 'Octubre 2026');
    expect(formats.month(DateTime(2027, 1, 20)), 'Enero 2027');
    expect(formats.monthShort(DateTime(2026, 10)), 'oct');
    expect(formats.monthShort(DateTime(2026, 9)), isNot(contains('.')));
  });

  group('formatCompactMoney', () {
    test('abrevia miles y millones para los ejes', () {
      expect(normalized(formats.compactMoney(0)), r'$0');
      expect(normalized(formats.compactMoney(500000)), r'$500 mil');
      expect(normalized(formats.compactMoney(1500000)), r'$1,5 M');
      expect(normalized(formats.compactMoney(4000000)), r'$4 M');
    });

    test('un negativo lleva el signo antes del símbolo', () {
      expect(normalized(formats.compactMoney(-500000)), r'-$500 mil');
      expect(normalized(formats.compactMoney(-1500000)), r'-$1,5 M');
    });
  });

  group('formatMoney', () {
    test('el símbolo va antes y el punto separa miles', () {
      expect(normalized(formats.money(1500000)), r'$1.500.000');
      expect(normalized(formats.money(-350000)), r'-$350.000');
    });

    test('los centavos solo aparecen si existen', () {
      expect(normalized(formats.money(1250000.5)), r'$1.250.000,50');
      expect(normalized(formats.money(0.1 + 0.2)), r'$0,30');
    });

    test('el ruido del punto flotante no genera centavos', () {
      expect(normalized(formats.money(1500000.0000000002)), r'$1.500.000');
    });

    test('otra moneda lleva su código', () {
      expect(normalized(formats.money(1500, currency: 'USD')), 'USD 1.500');
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

  group('en inglés', () {
    late Formats en;

    setUpAll(() async => en = await loadFormats('en'));

    test('el dinero lleva el símbolo antes, coma de miles y punto decimal', () {
      expect(normalized(en.money(1500000)), r'$1,500,000');
      expect(normalized(en.money(1250000.5)), r'$1,250,000.50');
      expect(normalized(en.money(-350000)), r'-$350,000');
    });

    test('el dinero abreviado de los ejes', () {
      expect(normalized(en.compactMoney(500000)), r'$500K');
      expect(normalized(en.compactMoney(1500000)), r'$1.5M');
      expect(normalized(en.compactMoney(-500000)), r'-$500K');
    });

    test('días: hoy, ayer, esta semana y otro año', () {
      final today = DateTime(2026, 10, 22);
      expect(en.day(DateTime(2026, 10, 22), today: today), 'Today');
      expect(en.day(DateTime(2026, 10, 21), today: today), 'Yesterday');
      expect(en.day(DateTime(2026, 10, 12), today: today), 'Monday, October 12');
      expect(en.day(DateTime(2025, 12, 31), today: today), 'December 31, 2025');
    });

    test('meses y fechas', () {
      expect(en.month(DateTime(2026, 10)), 'October 2026');
      expect(en.monthName(DateTime(2026, 9)), 'September');
      expect(en.monthShort(DateTime(2026, 10)), 'Oct');
      expect(en.dayMonth(DateTime(2026, 10, 12)), 'Oct 12');
      expect(en.fullDate(DateTime(2026, 3, 5)), 'March 5, 2026');
    });

    test('el separador de decimales es el punto', () {
      expect(en.decimalSeparator, '.');
      expect(formats.decimalSeparator, ',');
    });
  });
}
