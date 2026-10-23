import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/formats.dart';
import 'package:mi_plata/features/accounts/domain/amount_parser.dart';
import 'package:mi_plata/l10n/l10n.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;
late Formats formats;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    formats = Formats(l10n);
    await initDates();
  });

  group('parse', () {
    test('entiende el formato colombiano', () {
      const expected = {
        '1500000': '1500000',
        '1.500.000': '1500000',
        '1.500,50': '1500.50',
        '1500,5': '1500.5',
        '0,99': '0.99',
        '750': '750',
        '-200000': '-200000',
        '-1.250,75': '-1250.75',
        r'$ 25.000': '25000',
        '  3 000 ': '3000',
      };

      expected.forEach((input, normalized) {
        expect(AmountParser.parse(input, formats), normalized, reason: 'entrada "$input"');
      });
    });

    test('un texto vacío o nulo vale cero', () {
      expect(AmountParser.parse('', formats), '0');
      expect(AmountParser.parse('   ', formats), '0');
      expect(AmountParser.parse(null, formats), '0');
    });

    test('rechaza lo que no es un monto', () {
      for (final input in [
        'abc',
        '12.5', // el punto solo separa miles, en grupos de tres
        '1.50',
        '1,234', // máximo dos decimales
        '1,2,3',
        '1..000',
        '--5',
        '5-',
        '1.5e3',
      ]) {
        expect(AmountParser.parse(input, formats), isNull, reason: 'entrada "$input"');
      }
    });

    test('respeta el límite de numeric(14, 2)', () {
      expect(AmountParser.parse('999999999999', formats), '999999999999');
      expect(AmountParser.parse('9.999.999.999,99', formats), '9999999999.99');
      expect(AmountParser.parse('1000000000000', formats), isNull);
    });
  });

  group('toInput', () {
    test('muestra enteros sin decimales y el resto con coma', () {
      expect(AmountParser.toInput(1500000, formats), '1500000');
      expect(AmountParser.toInput(1500.5, formats), '1500,50');
      expect(AmountParser.toInput(-350000, formats), '-350000');
      expect(AmountParser.toInput(0, formats), '0');
    });

    test('lo que muestra se puede volver a leer igual', () {
      for (final value in [0.0, 1500000.0, 1500.5, -99.99, 123456.07]) {
        final text = AmountParser.toInput(value, formats);
        expect(double.parse(AmountParser.parse(text, formats)!), value);
      }
    });
  });

  group('en inglés', () {
    late Formats en;

    setUpAll(() async => en = await loadFormats('en'));

    test('la coma separa miles y el punto los decimales', () {
      const expected = {
        '1500000': '1500000',
        '1,500,000': '1500000',
        '1,500.50': '1500.50',
        '0.99': '0.99',
        '-1,250.75': '-1250.75',
        r'$ 25,000': '25000',
      };

      expected.forEach((input, normalized) {
        expect(AmountParser.parse(input, en), normalized, reason: 'entrada "$input"');
      });
    });

    test('rechaza el formato del otro idioma', () {
      for (final input in ['1.500.000', '1.500,50', '12,5', '1,234.567']) {
        expect(AmountParser.parse(input, en), isNull, reason: 'entrada "$input"');
      }
    });

    test('toInput escribe con punto decimal y se puede volver a leer', () {
      expect(AmountParser.toInput(1500.5, en), '1500.50');
      expect(AmountParser.toInput(1500000, en), '1500000');
      for (final value in [0.0, 1500.5, -99.99, 123456.07]) {
        expect(double.parse(AmountParser.parse(AmountParser.toInput(value, en), en)!), value);
      }
    });
  });
}
