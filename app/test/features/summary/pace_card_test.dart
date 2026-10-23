import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/summary/domain/month_summary.dart';
import 'package:mi_plata/features/summary/domain/monthly_total.dart';
import 'package:mi_plata/features/summary/presentation/widgets/pace_card.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/test_app.dart';

final oct = DateTime(2026, 10);
final sep = DateTime(2026, 9);

MonthSummary expenses(DateTime month, double total) => SummaryCalculator.forMonth(
  total == 0
      ? []
      : [
          MonthlyTotal(
            month: month,
            currency: 'COP',
            type: TransactionType.expense,
            categoryId: 'a',
            total: total,
            movements: 1,
          ),
        ],
  month,
);

Future<void> pump(
  WidgetTester tester, {
  required MonthSummary summary,
  required MonthSummary previous,
  required DateTime today,
}) => tester.pumpWidget(
  localizedApp(
    home: Scaffold(
      body: PaceCard(summary: summary, previous: previous, today: today),
    ),
  ),
);

void main() {
  setUpAll(initDates);

  testWidgets('en el mes en curso muestra promedio, proyección y base de cálculo', (
    tester,
  ) async {
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: expenses(sep, 200000),
      today: DateTime(2026, 10, 10),
    );

    expect(find.text('Promedio por día'), findsOneWidget);
    expect(textLike(r'$10.000'), findsOneWidget);
    expect(find.text('A este ritmo, el mes cerrará en'), findsOneWidget);
    expect(textLike(r'$310.000'), findsOneWidget);
    expect(find.text('Calculado sobre 10 de 31 días del mes.'), findsOneWidget);
  });

  testWidgets('compara la proyección con el gasto del mes anterior', (tester) async {
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: expenses(sep, 200000),
      today: DateTime(2026, 10, 10),
    );

    // 310.000 frente a 200.000: 55 % más. Es mala noticia, y lo dice el texto.
    expect(find.text('Proyección: 55 % más que en septiembre'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('una proyección menor al mes anterior dice "menos"', (tester) async {
    await pump(
      tester,
      summary: expenses(oct, 40000),
      previous: expenses(sep, 200000),
      today: DateTime(2026, 10, 10),
    );

    expect(find.text('Proyección: 38 % menos que en septiembre'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });

  testWidgets('sin datos del mes anterior no compara la proyección', (tester) async {
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: SummaryCalculator.forMonth([], sep),
      today: DateTime(2026, 10, 10),
    );

    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.textContaining('Proyección'), findsNothing);
    expect(find.text('A este ritmo, el mes cerrará en'), findsOneWidget);
  });

  testWidgets('con dos días de datos no proyecta, solo el promedio', (tester) async {
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: expenses(sep, 200000),
      today: DateTime(2026, 10, 2),
    );

    expect(find.text('Promedio por día'), findsOneWidget);
    expect(textLike(r'$50.000'), findsOneWidget); // 100.000 / 2 días
    expect(find.text('A este ritmo, el mes cerrará en'), findsNothing);
    expect(find.textContaining('Proyección'), findsNothing);
    expect(find.text('Calculado sobre 2 de 31 días del mes.'), findsOneWidget);
  });

  testWidgets('un mes terminado promedia sobre todos sus días y no proyecta', (
    tester,
  ) async {
    await pump(
      tester,
      summary: expenses(sep, 300000),
      previous: SummaryCalculator.forMonth([], DateTime(2026, 8)),
      today: DateTime(2026, 10, 22),
    );

    expect(textLike(r'$10.000'), findsOneWidget); // 300.000 / 30 días
    expect(find.text('Calculado sobre los 30 días del mes.'), findsOneWidget);
    expect(find.text('A este ritmo, el mes cerrará en'), findsNothing);
  });

  testWidgets('las estimaciones van en pesos enteros, sin centavos', (tester) async {
    // 100.000 en 3 días: 33.333,33 por día y 1.033.333,33 proyectados.
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: SummaryCalculator.forMonth([], sep),
      today: DateTime(2026, 10, 3),
    );

    expect(textLike(r'$33.333'), findsOneWidget);
    expect(textLike(r'$1.033.333'), findsOneWidget);
    // Ninguna cifra de dinero lleva decimales (la coma de las etiquetas no cuenta).
    final withCents = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'\$[\d.]+,\d{2}').hasMatch(widget.data ?? ''),
    );
    expect(withCents, findsNothing);
  });

  testWidgets('si el mes anterior no tuvo gastos lo dice con palabras', (tester) async {
    await pump(
      tester,
      summary: expenses(oct, 100000),
      previous: SummaryCalculator.forMonth([
        MonthlyTotal(
          month: sep,
          currency: 'COP',
          type: TransactionType.income,
          categoryId: null,
          total: 500000,
          movements: 1,
        ),
      ], sep),
      today: DateTime(2026, 10, 10),
    );

    expect(find.text('Proyección: Sin gastos en septiembre'), findsOneWidget);
  });

  testWidgets('sin gastos el promedio es cero', (tester) async {
    await pump(
      tester,
      summary: SummaryCalculator.forMonth([], oct),
      previous: expenses(sep, 100000),
      today: DateTime(2026, 10, 15),
    );

    expect(textLike(r'$0'), findsWidgets);
  });
}
