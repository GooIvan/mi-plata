import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/summary/presentation/summary_comparison.dart';

ComparisonCaption? compare(
  int current,
  int previous, {
  bool previousHasData = true,
}) => compareWithPrevious(
  current: current,
  previous: previous,
  previousHasData: previousHasData,
  previousMonthName: 'septiembre',
);

void main() {
  group('frases', () {
    test('subir: porcentaje redondeado, "más que en <mes>" y flecha hacia arriba', () {
      final caption = compare(11240, 10000)!;

      expect(caption.text, '12 % más que en septiembre');
      expect(caption.icon, Icons.arrow_upward);
    });

    test('bajar: "menos que en <mes>" y flecha hacia abajo', () {
      final caption = compare(5000, 10000)!;

      expect(caption.text, '50 % menos que en septiembre');
      expect(caption.icon, Icons.arrow_downward);
    });

    test('igual', () {
      final caption = compare(7000, 7000)!;

      expect(caption.text, 'Igual que en septiembre');
      expect(caption.icon, Icons.remove);
    });

    test('un cambio minúsculo no se redondea a cero', () {
      expect(compare(100001, 100000)!.text, '<1 % más que en septiembre');
      expect(compare(99999, 100000)!.text, '<1 % menos que en septiembre');
    });

    test('si antes era cero no hay porcentaje: dice lo que había', () {
      final caption = compare(5000, 0)!;

      expect(caption.text, r'$0 en septiembre');
      expect(caption.change.isUp, isTrue);
    });

    test('con un sustantivo, el caso "antes no había" se dice con palabras', () {
      final caption = compareWithPrevious(
        current: 5000,
        previous: 0,
        previousHasData: true,
        previousMonthName: 'septiembre',
        noneNoun: 'gastos',
      )!;

      expect(caption.text, 'Sin gastos en septiembre');
    });

    test('puede superar el 100 %', () {
      expect(compare(30000, 10000)!.text, '200 % más que en septiembre');
    });
  });

  group('cuándo no hay nada que decir', () {
    test('si el mes anterior no tuvo movimientos', () {
      expect(compare(5000, 0, previousHasData: false), isNull);
    });

    test('si la cifra fue cero en los dos meses', () {
      expect(compare(0, 0), isNull);
    });

    test('pero si antes había y ahora es cero, sí dice que bajó', () {
      expect(compare(0, 10000)!.text, '100 % menos que en septiembre');
    });
  });

  group('color', () {
    const colors = ColorScheme.light();

    test('si subir es bueno (ingresos), subir es primario y bajar es error', () {
      expect(compare(200, 100)!.color(colors, upIsGood: true), colors.primary);
      expect(compare(50, 100)!.color(colors, upIsGood: true), colors.error);
    });

    test('si subir es malo (gastos), subir es error y bajar es primario', () {
      expect(compare(200, 100)!.color(colors, upIsGood: false), colors.error);
      expect(compare(50, 100)!.color(colors, upIsGood: false), colors.primary);
    });

    test('sin cambio no lleva color', () {
      expect(compare(100, 100)!.color(colors, upIsGood: true), isNull);
      expect(compare(100, 100)!.color(colors, upIsGood: false), isNull);
    });
  });
}
