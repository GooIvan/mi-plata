import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/summary/domain/balance_history.dart';
import 'package:mi_plata/features/summary/presentation/widgets/balance_history_card.dart';

import '../../support/test_app.dart';

/// Seis meses de mayo a octubre de 2026, con estos saldos (en pesos).
List<BalancePoint> months(List<int> pesos) => [
  for (var i = 0; i < pesos.length; i++)
    BalancePoint(month: DateTime(2026, 5 + i), cents: pesos[i] * 100),
];

Future<void> pump(WidgetTester tester, List<int> pesos) => tester.pumpWidget(
  localizedApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BalanceHistoryCard(
          points: months(pesos),
          selectedMonth: DateTime(2026, 10),
          currency: 'COP',
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(initDates);

  testWidgets('el título, el último valor y un gráfico de línea', (tester) async {
    await pump(tester, [1000000, 1100000, 1200000, 1250000, 1400000, 1750000]);

    expect(find.text('Dinero total'), findsOneWidget);
    expect(find.text('Al cierre de cada mes'), findsOneWidget);
    expect(textLike(r'$1.750.000'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('si subió, lo dice con flecha hacia arriba', (tester) async {
    await pump(tester, [1000000, 1100000, 1200000, 1250000, 1400000, 1750000]);

    expect(find.text(r'$750.000 más que hace 5 meses'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('si bajó, lo dice con flecha hacia abajo', (tester) async {
    await pump(tester, [1750000, 1400000, 1250000, 1200000, 1100000, 1000000]);

    expect(find.text(r'$750.000 menos que hace 5 meses'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });

  testWidgets('si no cambió, dice que es igual', (tester) async {
    await pump(tester, [500000, 600000, 400000, 500000, 700000, 500000]);

    expect(find.text('Igual que hace 5 meses'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('el dinero total puede ser negativo', (tester) async {
    await pump(tester, [100000, 50000, 0, -50000, -120000, -250000]);

    expect(textLike(r'-$250.000'), findsOneWidget);
    expect(find.text(r'$350.000 menos que hace 5 meses'), findsOneWidget);
  });

  testWidgets('la tabla tiene el cierre de cada mes y se puede ocultar', (tester) async {
    await pump(tester, [1000000, 1100000, 1200000, 1250000, 1400000, 1750000]);
    expect(find.text('Cierre de'), findsNothing);

    await tester.tap(find.text('Ver saldos como tabla'));
    await tester.pumpAndSettle();

    expect(find.text('Cierre de'), findsOneWidget);
    expect(find.text('Mayo 2026'), findsOneWidget);
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(textLike(r'$1.250.000'), findsOneWidget);

    await tester.tap(find.text('Ocultar tabla de saldos'));
    await tester.pumpAndSettle();
    expect(find.text('Cierre de'), findsNothing);
  });

  testWidgets('una línea plana no rompe el eje', (tester) async {
    await pump(tester, [800000, 800000, 800000, 800000, 800000, 800000]);

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
