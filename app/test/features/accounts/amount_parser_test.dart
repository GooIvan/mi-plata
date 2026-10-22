import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/amount_parser.dart';

void main() {
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
        expect(AmountParser.parse(input), normalized, reason: 'entrada "$input"');
      });
    });

    test('un texto vacío o nulo vale cero', () {
      expect(AmountParser.parse(''), '0');
      expect(AmountParser.parse('   '), '0');
      expect(AmountParser.parse(null), '0');
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
        expect(AmountParser.parse(input), isNull, reason: 'entrada "$input"');
      }
    });

    test('respeta el límite de numeric(14, 2)', () {
      expect(AmountParser.parse('999999999999'), '999999999999');
      expect(AmountParser.parse('9.999.999.999,99'), '9999999999.99');
      expect(AmountParser.parse('1000000000000'), isNull);
    });
  });

  group('toInput', () {
    test('muestra enteros sin decimales y el resto con coma', () {
      expect(AmountParser.toInput(1500000), '1500000');
      expect(AmountParser.toInput(1500.5), '1500,50');
      expect(AmountParser.toInput(-350000), '-350000');
      expect(AmountParser.toInput(0), '0');
    });

    test('lo que muestra se puede volver a leer igual', () {
      for (final value in [0.0, 1500000.0, 1500.5, -99.99, 123456.07]) {
        final text = AmountParser.toInput(value);
        expect(double.parse(AmountParser.parse(text)!), value);
      }
    });
  });
}
