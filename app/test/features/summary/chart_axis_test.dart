import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/summary/presentation/widgets/monthly_trend_chart.dart';

void main() {
  ({double step, double max}) axis(double highest) =>
      MonthlyTrendChart.axisFor(highest);

  test('el eje aprovecha la altura: 4,55 M llega a 5 M, no a 8 M', () {
    expect(axis(4550000), (step: 1000000, max: 5000000));
  });

  test('usa pasos redondos: 1, 2, 2,5 o 5 por una potencia de diez', () {
    expect(axis(900000), (step: 200000, max: 1000000));
    expect(axis(12300000), (step: 2500000, max: 12500000));
    expect(axis(380000), (step: 100000, max: 400000));
    expect(axis(7), (step: 2, max: 8));
  });

  test('un valor justo en una marca no suma un tramo de más', () {
    expect(axis(5000000), (step: 1000000, max: 5000000));
    expect(axis(1000000), (step: 200000, max: 1000000));
  });

  test('nunca hay más de cinco tramos y el máximo cubre el valor', () {
    for (final highest in [1.0, 37.0, 999.0, 123456.0, 4550000.0, 98765432.0]) {
      final result = axis(highest);
      expect(result.max, greaterThanOrEqualTo(highest), reason: '$highest');
      expect(result.max / result.step, lessThanOrEqualTo(5), reason: '$highest');
    }
  });

  test('sin datos usa un eje pequeño de cuatro tramos', () {
    expect(axis(0), (step: 1000, max: 4000));
  });
}
