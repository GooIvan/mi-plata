import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/date_format.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();

/// Un día del mes actual.
DateTime thisMonth([int day = 5]) => DateTime(_now.year, _now.month, day);

/// Un día de un mes anterior (1 = el mes pasado).
DateTime monthsAgo(int months, [int day = 10]) =>
    DateTime(_now.year, _now.month - months, day);

int _next = 0;

Transaction tx(
  TransactionType type,
  double amount, {
  String? category,
  DateTime? date,
}) => testTransaction(
  'tx-${_next++}',
  type: type,
  accountId: 'id-Bancolombia',
  destinationAccountId: type == TransactionType.transfer ? 'id-Otra' : null,
  categoryId: category == null ? null : 'cat-$category',
  amount: amount,
  date: date ?? thisMonth(),
);

final _categories = <Category>[
  testCategory('Salario', CategoryType.income),
  testCategory('Mercado', CategoryType.expense),
  testCategory('Transporte', CategoryType.expense),
];

const _income = TransactionType.income;
const _expense = TransactionType.expense;

/// Abre la app y entra al resumen mensual desde el panel.
Future<FakeBackend> openSummary(
  WidgetTester tester, {
  List<Transaction> transactions = const [],
  List<Category>? categories,
  List<Account>? accounts,
}) async {
  // Una pantalla alta: la lista se construye bajo demanda y así todo cabe.
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final backend = FakeBackend(
    accounts: accounts ?? [testAccount('Bancolombia')],
    categories: categories ?? _categories,
    transactions: transactions,
  );
  await pumpMiPlata(tester, backend: backend);
  await tester.tap(find.byTooltip('Resumen mensual'));
  await tester.pumpAndSettle();
  return backend;
}

Finder tile(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(Card),
);

void main() {
  setUpAll(initDates);

  group('totales del mes', () {
    final october = [
      tx(_income, 3000000, category: 'Salario'),
      tx(_expense, 700000, category: 'Mercado'),
      tx(_expense, 300000, category: 'Transporte'),
      // Una transferencia mueve dinero entre cuentas: no es ingreso ni gasto.
      tx(TransactionType.transfer, 999999),
    ];

    testWidgets('se abre desde el panel en el mes actual', (tester) async {
      await openSummary(tester, transactions: october);

      expect(find.widgetWithText(AppBar, 'Resumen mensual'), findsOneWidget);
      expect(find.text(formatMonth(_now)), findsWidgets);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('muestra ingresos, gastos y balance, sin las transferencias', (
      tester,
    ) async {
      await openSummary(tester, transactions: october);

      expect(find.text('Balance del mes'), findsOneWidget);
      expect(textLike(r'$2.000.000'), findsOneWidget); // 3.000.000 - 1.000.000
      expect(
        find.descendant(of: tile('Ingresos').first, matching: textLike(r'$3.000.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile('Gastos').first, matching: textLike(r'$1.000.000')),
        findsOneWidget,
      );
    });

    testWidgets('el balance explica si sobró o faltó dinero', (tester) async {
      await openSummary(tester, transactions: [tx(_income, 100000)]);
      expect(find.text('Ingresaste más de lo que gastaste'), findsOneWidget);
    });

    testWidgets('con un balance negativo lo dice y lleva signo menos', (
      tester,
    ) async {
      await openSummary(
        tester,
        transactions: [tx(_income, 100000), tx(_expense, 350000)],
      );

      expect(find.text('Gastaste más de lo que ingresaste'), findsOneWidget);
      expect(
        find.descendant(
          of: tile('Balance del mes').first,
          matching: textLike(r'-$250.000'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con ingresos y gastos iguales lo dice', (tester) async {
      await openSummary(
        tester,
        transactions: [tx(_income, 5000), tx(_expense, 5000)],
      );
      expect(find.text('Ingresos y gastos iguales'), findsOneWidget);
    });

    testWidgets('un mes sin movimientos, si hay otros, muestra ceros', (
      tester,
    ) async {
      await openSummary(
        tester,
        transactions: [tx(_expense, 250000, category: 'Mercado', date: monthsAgo(1))],
      );

      for (final label in ['Balance del mes', 'Ingresos', 'Gastos']) {
        expect(
          find.descendant(of: tile(label).first, matching: textLike(r'$0')),
          findsOneWidget,
          reason: 'tarjeta "$label"',
        );
      }
      expect(find.text('No hay gastos en este mes.'), findsOneWidget);
    });

    testWidgets('sin ningún movimiento invita a registrar uno', (tester) async {
      await openSummary(tester);

      expect(find.textContaining('Aún no hay movimientos para resumir'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Registrar movimiento'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Nuevo movimiento'), findsOneWidget);
    });
  });

  group('reparto por categoría', () {
    testWidgets('ordena de mayor a menor con cifra y porcentaje', (tester) async {
      await openSummary(
        tester,
        transactions: [
          tx(_expense, 300000, category: 'Transporte'),
          tx(_expense, 700000, category: 'Mercado'),
        ],
      );

      expect(find.text('¿En qué se va el dinero?'), findsOneWidget);
      expect(find.text('70 %'), findsOneWidget);
      expect(find.text('30 %'), findsOneWidget);

      final mercado = tester.getTopLeft(find.text('Mercado')).dy;
      final transporte = tester.getTopLeft(find.text('Transporte')).dy;
      expect(mercado, lessThan(transporte));
    });

    testWidgets('los movimientos sin categoría aparecen como "Sin categoría"', (
      tester,
    ) async {
      await openSummary(
        tester,
        transactions: [
          tx(_expense, 800000, category: 'Mercado'),
          tx(_expense, 200000),
        ],
      );

      expect(find.text('Sin categoría'), findsOneWidget);
      expect(find.text('20 %'), findsOneWidget);
    });

    testWidgets('el selector cambia al reparto de ingresos', (tester) async {
      await openSummary(
        tester,
        transactions: [
          tx(_income, 4000000, category: 'Salario'),
          tx(_expense, 700000, category: 'Mercado'),
        ],
      );
      expect(find.text('Mercado'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TransactionType>),
          matching: find.text('Ingresos'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿De dónde viene?'), findsOneWidget);
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
      expect(find.text('100 %'), findsOneWidget);
    });

    testWidgets('un mes sin ingresos lo dice en el reparto de ingresos', (
      tester,
    ) async {
      await openSummary(
        tester,
        transactions: [tx(_expense, 700000, category: 'Mercado')],
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TransactionType>),
          matching: find.text('Ingresos'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay ingresos en este mes.'), findsOneWidget);
    });

    testWidgets('con muchas categorías agrupa las pequeñas en "Otras"', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 10; i++) testCategory('Cat $i', CategoryType.expense),
      ];
      await openSummary(
        tester,
        categories: many,
        transactions: [
          for (var i = 0; i < 10; i++)
            tx(_expense, 1000.0 * (10 - i), category: 'Cat $i'),
        ],
      );

      expect(find.text('Cat 0'), findsOneWidget);
      expect(find.text('Cat 6'), findsOneWidget);
      expect(find.text('Cat 7'), findsNothing);
      expect(find.text('Otras'), findsOneWidget);
    });
  });

  group('navegación entre meses', () {
    final data = [
      tx(_expense, 111000, category: 'Mercado'),
      tx(_expense, 250000, category: 'Mercado', date: monthsAgo(1)),
    ];

    testWidgets('el mes actual no tiene siguiente', (tester) async {
      await openSummary(tester, transactions: data);

      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('ir al mes anterior muestra sus cifras, y se puede volver', (
      tester,
    ) async {
      await openSummary(tester, transactions: data);
      expect(textLike(r'$111.000'), findsWidgets);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text(formatMonth(monthsAgo(1))), findsOneWidget);
      expect(
        find.descendant(of: tile('Gastos').first, matching: textLike(r'$250.000')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tile('Gastos').first, matching: textLike(r'$111.000')),
        findsOneWidget,
      );
    });

    testWidgets('pide al servidor los seis meses que terminan en el elegido', (
      tester,
    ) async {
      final backend = await openSummary(tester, transactions: data);

      final request = backend.summary.requests.first;
      expect(request.to, DateTime(_now.year, _now.month));
      expect(request.from, DateTime(_now.year, _now.month - 5));
    });

    testWidgets('mientras carga otro mes mantiene lo anterior atenuado', (
      tester,
    ) async {
      final backend = await openSummary(tester, transactions: data);

      backend.summary.gate = Completer<void>();
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pump();

      // Sigue visible el mes anterior (el contenido, no un indicador de carga).
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(textLike(r'$111.000'), findsWidgets);
      final faded = tester.widgetList<Opacity>(find.byType(Opacity)).any(
        (opacity) => opacity.opacity == 0.5,
      );
      expect(faded, isTrue);

      backend.summary.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.descendant(of: tile('Gastos').first, matching: textLike(r'$250.000')),
        findsOneWidget,
      );
    });
  });

  group('gráfico de tendencia', () {
    final data = [
      tx(_income, 3000000, category: 'Salario'),
      tx(_expense, 1000000, category: 'Mercado'),
      tx(_expense, 400000, category: 'Mercado', date: monthsAgo(3)),
    ];

    testWidgets('tiene título, leyenda y los últimos seis meses', (tester) async {
      await openSummary(tester, transactions: data);

      expect(find.text('Ingresos vs. gastos'), findsOneWidget);
      expect(find.text('Últimos 6 meses'), findsOneWidget);
      // La leyenda y las tarjetas comparten las etiquetas.
      expect(find.text('Ingresos'), findsWidgets);
      expect(find.text('Gastos'), findsWidgets);
    });

    testWidgets('la tabla tiene las mismas cifras que el gráfico', (tester) async {
      await openSummary(tester, transactions: data);

      expect(find.text(formatMonth(monthsAgo(5, 1))), findsNothing);

      await tester.tap(find.text('Ver como tabla'));
      await tester.pumpAndSettle();

      // Los seis meses, del más viejo al actual.
      for (var i = 5; i >= 0; i--) {
        expect(find.text(formatMonth(monthsAgo(i, 1))), findsWidgets);
      }
      expect(find.text('Ocultar tabla'), findsOneWidget);
      expect(textLike(r'$400.000'), findsOneWidget); // el gasto de hace 3 meses

      await tester.tap(find.text('Ocultar tabla'));
      await tester.pumpAndSettle();
      expect(find.text('Ver como tabla'), findsOneWidget);
      expect(textLike(r'$400.000'), findsNothing);
    });
  });

  group('errores', () {
    testWidgets('si falla la carga muestra el error y permite reintentar', (
      tester,
    ) async {
      final backend = FakeBackend(accounts: [testAccount('Bancolombia')]);
      backend.summary.error = const PostgrestException(message: 'boom', code: '500');
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpMiPlata(tester, backend: backend);
      await tester.tap(find.byTooltip('Resumen mensual'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo cargar el resumen'), findsOneWidget);

      backend.summary.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo cargar'), findsNothing);
      expect(find.textContaining('Aún no hay movimientos'), findsOneWidget);
    });
  });

  group('comparación con el mes anterior', () {
    // Perezoso: los datos de fecha se inicializan en setUpAll, después de
    // declarar el grupo.
    late final previousName = formatMonthName(monthsAgo(1));

    // Este mes: ingresos 3.000.000 y gastos 161.000 (Mercado 111.000).
    // Mes anterior: ingresos 2.000.000 y gastos 150.000 (Mercado 100.000).
    final both = [
      tx(_income, 3000000, category: 'Salario'),
      tx(_expense, 111000, category: 'Mercado'),
      tx(_expense, 50000, category: 'Transporte'),
      tx(_income, 2000000, category: 'Salario', date: monthsAgo(1)),
      tx(_expense, 100000, category: 'Mercado', date: monthsAgo(1)),
      tx(_expense, 50000, category: 'Transporte', date: monthsAgo(1)),
    ];

    testWidgets('las tarjetas comparan ingresos y gastos', (tester) async {
      await openSummary(tester, transactions: both);

      expect(
        find.descendant(
          of: tile('Ingresos').first,
          matching: find.text('50 % más que en $previousName'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('Gastos').first,
          matching: find.text('7 % más que en $previousName'), // 161 / 150
        ),
        findsOneWidget,
      );
    });

    testWidgets('cada categoría dice cómo cambió', (tester) async {
      await openSummary(tester, transactions: both);

      expect(find.text('11 % más que en $previousName'), findsOneWidget); // Mercado
      expect(find.text('Igual que en $previousName'), findsOneWidget); // Transporte
    });

    testWidgets('un gasto que baja dice "menos"', (tester) async {
      await openSummary(
        tester,
        transactions: [
          tx(_expense, 90000, category: 'Mercado'),
          tx(_expense, 100000, category: 'Mercado', date: monthsAgo(1)),
        ],
      );

      expect(find.text('10 % menos que en $previousName'), findsWidgets);
    });

    testWidgets('el reparto de ingresos compara con los ingresos', (tester) async {
      await openSummary(tester, transactions: both);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TransactionType>),
          matching: find.text('Ingresos'),
        ),
      );
      await tester.pumpAndSettle();

      // La tarjeta de ingresos y la fila de "Salario".
      expect(find.text('50 % más que en $previousName'), findsNWidgets(2));
    });

    testWidgets('una categoría nueva dice lo que había antes: cero', (tester) async {
      await openSummary(
        tester,
        transactions: [
          tx(_expense, 40000, category: 'Transporte'),
          tx(_expense, 100000, category: 'Mercado', date: monthsAgo(1)),
        ],
      );

      // Transporte no tuvo gastos el mes anterior: lo dice con palabras.
      expect(find.text('Sin gastos en $previousName'), findsWidgets);
    });

    testWidgets('si el mes anterior no tuvo movimientos no compara', (tester) async {
      await openSummary(
        tester,
        transactions: [tx(_expense, 100000, category: 'Mercado')],
      );

      expect(find.textContaining('que en $previousName'), findsNothing);
      expect(find.textContaining(' en $previousName'), findsNothing);
    });
  });

  group('dinero total a lo largo del tiempo', () {
    // Banco empieza con 1.000.000. El mes pasado gastó 250.000 y este mes
    // ingresó 3.000.000 y gastó 1.000.000: cierra el mes pasado en 750.000 y
    // este mes en 2.750.000.
    final data = [
      tx(_expense, 250000, category: 'Mercado', date: monthsAgo(1)),
      tx(_income, 3000000, category: 'Salario'),
      tx(_expense, 1000000, category: 'Mercado'),
    ];
    final accounts = [testAccount('Bancolombia', balance: 1000000)];

    Finder card() => find.ancestor(
      of: find.text('Al cierre de cada mes'),
      matching: find.byType(Card),
    );

    testWidgets('muestra el dinero total al cierre del mes y cuánto cambió', (
      tester,
    ) async {
      await openSummary(tester, transactions: data, accounts: accounts);

      expect(find.text('Dinero total'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(
        find.descendant(of: card().first, matching: textLike(r'$2.750.000')),
        findsOneWidget,
      );
      // Hace cinco meses había 1.000.000: son 1.750.000 más.
      expect(find.text(r'$1.750.000 más que hace 5 meses'), findsOneWidget);
    });

    testWidgets('al ir al mes anterior muestra su cierre, sin volver a consultar', (
      tester,
    ) async {
      final backend = await openSummary(tester, transactions: data, accounts: accounts);
      expect(backend.summary.flowRequests, 1);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: card().first, matching: textLike(r'$750.000')),
        findsOneWidget,
      );
      // Los flujos son de todo el historial: cambiar de mes no los pide otra vez.
      expect(backend.summary.flowRequests, 1);
    });

    testWidgets('la tabla trae el cierre de cada uno de los seis meses', (tester) async {
      await openSummary(tester, transactions: data, accounts: accounts);

      await tester.tap(find.text('Ver saldos como tabla'));
      await tester.pumpAndSettle();

      expect(find.text('Cierre de'), findsOneWidget);
      expect(find.text('Ocultar tabla de saldos'), findsOneWidget);
      // Cuatro meses con 1.000.000, el mes pasado con 750.000 y este con
      // 2.750.000 (en la tarjeta: el mismo monto sale en otras tarjetas).
      Finder inCard(String amount) =>
          find.descendant(of: card().first, matching: textLike(amount));
      expect(inCard(r'$1.000.000'), findsNWidgets(4));
      expect(inCard(r'$750.000'), findsOneWidget);
      expect(inCard(r'$2.750.000'), findsNWidgets(2)); // el encabezado y la tabla
    });

    testWidgets('no aparece si todas las cuentas están archivadas', (tester) async {
      await openSummary(
        tester,
        transactions: data,
        accounts: [testAccount('Vieja', balance: 500, archived: true)],
      );

      expect(find.text('Al cierre de cada mes'), findsNothing);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('si falla la carga lo dice y permite reintentar', (tester) async {
      final backend = FakeBackend(
        accounts: accounts,
        categories: _categories,
        transactions: data,
      );
      backend.summary.flowsError = const PostgrestException(message: 'boom', code: '500');
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpMiPlata(tester, backend: backend);
      await tester.tap(find.byTooltip('Resumen mensual'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar la evolución del dinero.'), findsOneWidget);
      // Lo demás del resumen sigue ahí.
      expect(find.text('Balance del mes'), findsOneWidget);

      backend.summary.flowsError = null;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar la evolución del dinero.'), findsNothing);
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  testWidgets('la tarjeta de ritmo de gasto aparece en el resumen', (tester) async {
    await openSummary(
      tester,
      transactions: [tx(_expense, 100000, category: 'Mercado')],
    );

    expect(find.text('Ritmo de gasto'), findsOneWidget);
    expect(find.text('Promedio por día'), findsOneWidget);
  });
}
