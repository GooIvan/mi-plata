import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_filter.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_list_providers.dart';
import 'package:mi_plata/features/transactions/presentation/transactions_screen.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

int _next = 0;

Transaction tx(
  String description,
  double amount, {
  TransactionType type = TransactionType.expense,
  String account = 'id-Bancolombia',
  String? destination,
  String? category,
  required DateTime date,
}) => testTransaction(
  't${_next++}',
  type: type,
  accountId: account,
  destinationAccountId: destination,
  categoryId: category == null ? null : 'cat-$category',
  amount: amount,
  date: date,
  description: description,
);

DateTime day(int n) => DateTime(2026, 1, 1 + n);

/// [count] movimientos de un gasto cada uno, del más viejo ('Compra 0') al más
/// reciente ('Compra N-1'), uno por día.
List<Transaction> many(int count) => [
  for (var i = 0; i < count; i++) tx('Compra $i', 1000.0 + i, date: day(i)),
];

FakeBackend backendWith(List<Transaction> transactions) => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Nequi', type: AccountType.wallet, balance: 50000),
  ],
  categories: [
    testCategory('Mercado', CategoryType.expense),
    testCategory('Salario', CategoryType.income),
  ],
  transactions: transactions,
);

Future<FakeBackend> openList(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpMiPlata(tester, backend: backend);
  await goTo(tester, AppRoutes.transactions);
  return backend;
}

List<int> offsets(FakeBackend backend) =>
    backend.transactions.pageRequests.map((r) => r.offset).toList();

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TransactionsScreen)));

Future<void> openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtrar'));
  await tester.pumpAndSettle();
}

Future<void> apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder filterDropdown(int index) =>
    find.byType(DropdownButtonFormField<String?>).at(index);

void main() {
  setUpAll(initDates);

  group('paginación', () {
    testWidgets('carga la primera página y pide más al llegar al final', (
      tester,
    ) async {
      final backend = await openList(tester, backendWith(many(100)));

      expect(offsets(backend), [0]);
      expect(find.text('Compra 99'), findsOneWidget); // el más reciente primero

      await tester.scrollUntilVisible(find.text('Compra 0'), 500, maxScrolls: 400);
      await tester.pumpAndSettle();

      // Las tres páginas: 40 + 40 + 20, y no se pide una cuarta.
      expect(offsets(backend), [0, 40, 80]);
      expect(find.text('Compra 0'), findsOneWidget);
    });

    testWidgets('al llegar al final de todo, ya no hay indicador de carga', (
      tester,
    ) async {
      await openList(tester, backendWith(many(100)));

      await tester.scrollUntilVisible(find.text('Compra 0'), 500, maxScrolls: 400);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('con menos de una página no pide otra', (tester) async {
      final backend = await openList(tester, backendWith(many(10)));
      await tester.pumpAndSettle();

      expect(offsets(backend), [0]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('una página exactamente llena pide la siguiente, que llega vacía', (
      tester,
    ) async {
      final backend = await openList(tester, backendWith(many(40)));

      await tester.scrollUntilVisible(find.text('Compra 0'), 500, maxScrolls: 200);
      await tester.pumpAndSettle();

      expect(offsets(backend), [0, 40]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('si falla una página posterior ofrece reintentar', (tester) async {
      final backend = backendWith(many(100));
      backend.transactions.failLaterPages = true;
      await openList(tester, backend);

      await tester.scrollUntilVisible(
        find.text('No se pudieron cargar más movimientos.'),
        500,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar más movimientos.'), findsOneWidget);
      // Lo que ya estaba cargado sigue ahí.
      expect(find.text('Compra 60'), findsOneWidget);

      backend.transactions.failLaterPages = false;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      // Se vuelve a pedir la misma página que había fallado, no se salta.
      expect(find.text('No se pudieron cargar más movimientos.'), findsNothing);
      expect(offsets(backend), [0, 40, 40]);
    });

    testWidgets('los encabezados de día siguen apareciendo al cargar más páginas', (
      tester,
    ) async {
      await openList(tester, backendWith(many(60)));

      await tester.scrollUntilVisible(find.text('Compra 0'), 500, maxScrolls: 300);
      await tester.pumpAndSettle();

      // 1 de enero de 2026 es el día del movimiento más viejo.
      expect(find.text('Jueves 1 de enero'), findsOneWidget);
    });
  });

  group('búsqueda', () {
    final data = [
      tx('Mercado Éxito', 120000, date: day(3)),
      tx('Rappi hamburguesa', 35000, date: day(2)),
      tx('Netflix', 24000, date: day(1)),
      tx('Rappi mercado', 80000, date: day(0)),
    ];

    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 500)); // la espera
      await tester.pumpAndSettle();
    }

    testWidgets('busca en la descripción, sin importar mayúsculas', (tester) async {
      await openList(tester, backendWith(data));

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await search(tester, 'RAPPI');

      expect(find.text('Rappi hamburguesa'), findsOneWidget);
      expect(find.text('Rappi mercado'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
      expect(find.text('Mercado Éxito'), findsNothing);
    });

    testWidgets('espera a que termines de escribir: una sola búsqueda', (tester) async {
      final backend = await openList(tester, backendWith(data));
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      final before = backend.transactions.pageRequests.length;

      await tester.enterText(find.byType(TextField), 'r');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ra');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'rap');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final texts = backend.transactions.pageRequests
          .skip(before)
          .map((r) => r.filter.text)
          .toList();
      expect(texts, ['rap']);
    });

    testWidgets('sin coincidencias lo dice y permite limpiar', (tester) async {
      await openList(tester, backendWith(data));
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      await search(tester, 'zzz');

      expect(find.text('No hay movimientos con estos filtros.'), findsOneWidget);
    });

    testWidgets('cerrar la búsqueda vuelve a mostrar todo', (tester) async {
      await openList(tester, backendWith(data));
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await search(tester, 'netflix');
      expect(find.text('Rappi mercado'), findsNothing);

      await tester.tap(find.byTooltip('Cerrar búsqueda'));
      await tester.pumpAndSettle();

      expect(find.text('Movimientos'), findsWidgets);
      expect(find.text('Rappi mercado'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('un % o _ se busca tal cual, no como comodín', (tester) async {
      final backend = backendWith([
        tx('Descuento 50% ropa', 10000, date: day(1)),
        tx('Cuota 50 de 100', 20000, date: day(0)),
      ]);
      await openList(tester, backend);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      await search(tester, '50%');

      expect(find.text('Descuento 50% ropa'), findsOneWidget);
      expect(find.text('Cuota 50 de 100'), findsNothing);
    });
  });

  group('filtros', () {
    final data = [
      tx('Mercado', 120000, category: 'Mercado', date: day(5)),
      tx('Cena', 60000, date: day(4)), // sin categoría
      tx('Sueldo', 3000000, type: TransactionType.income, category: 'Salario', date: day(3)),
      tx('Pasaje', 8000, account: 'id-Nequi', date: day(2)),
      tx('Paso a Nequi', 200000,
          type: TransactionType.transfer, destination: 'id-Nequi', date: day(1)),
      tx('Otro mercado', 45000, category: 'Mercado', date: day(0)),
    ];

    testWidgets('sin filtros no hay etiquetas ni número en el botón', (tester) async {
      await openList(tester, backendWith(data));

      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('por tipo', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      await apply(tester);

      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Ingresos'), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    });

    testWidgets('por cuenta: incluye lo que sale y lo que entra', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);

      await pick(tester, filterDropdown(0), 'Nequi');
      await apply(tester);

      expect(find.text('Pasaje'), findsOneWidget); // salió de Nequi
      expect(find.text('Paso a Nequi'), findsOneWidget); // entró a Nequi
      expect(find.text('Mercado'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Nequi'), findsOneWidget);
    });

    testWidgets('por categoría', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);

      await pick(tester, filterDropdown(1), 'Mercado');
      await apply(tester);

      expect(find.text('Mercado'), findsWidgets);
      expect(find.text('Otro mercado'), findsOneWidget);
      expect(find.text('Cena'), findsNothing);
      expect(find.text('Sueldo'), findsNothing);
    });

    testWidgets('solo los que no tienen categoría', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);

      await pick(tester, filterDropdown(1), 'Sin categoría');
      await apply(tester);

      expect(find.text('Cena'), findsOneWidget);
      expect(find.text('Pasaje'), findsOneWidget);
      expect(find.text('Sueldo'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Sin categoría'), findsOneWidget);
    });

    testWidgets('por fechas, con las etiquetas "del … al …"', (tester) async {
      await openList(tester, backendWith(data));

      containerOf(tester)
          .read(transactionFilterProvider.notifier)
          .set(TransactionFilter.empty.withRange(day(2), day(4)));
      await tester.pumpAndSettle();

      // Del 3 al 5 de enero: Pasaje (día 2 → 3 ene), Sueldo y Cena.
      expect(find.text('Cena'), findsOneWidget);
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('Pasaje'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
      expect(find.text('Otro mercado'), findsNothing);
      expect(find.widgetWithText(InputChip, 'del 3 ene al 5 ene'), findsOneWidget);
    });

    testWidgets('varios filtros se combinan', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gastos'));
      await tester.pumpAndSettle();
      await pick(tester, filterDropdown(1), 'Mercado');
      await apply(tester);

      expect(find.text('Otro mercado'), findsOneWidget);
      expect(find.text('Cena'), findsNothing);
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(tester.widget<Badge>(find.byType(Badge)).label, isA<Text>());
    });

    testWidgets('quitar una etiqueta quita solo ese filtro', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gastos'));
      await tester.pumpAndSettle();
      await pick(tester, filterDropdown(1), 'Mercado');
      await apply(tester);

      await tester.tap(find.byTooltip('Quitar filtro: Gastos'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Gastos'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Mercado'), findsOneWidget);
    });

    testWidgets('"Limpiar filtros" los quita todos', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      await apply(tester);
      expect(find.text('Cena'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Cena'), findsOneWidget);
    });

    testWidgets('el botón "Limpiar" de la hoja deja todo sin filtros', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      await apply(tester);

      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpiar'));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Cena'), findsOneWidget);
    });

    testWidgets('cerrar la hoja sin aplicar no cambia nada', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // fuera de la hoja
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Cena'), findsOneWidget);
    });

    testWidgets('sin resultados ofrece limpiar los filtros', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Transferencias'));
      await tester.pumpAndSettle();
      await pick(tester, filterDropdown(1), 'Mercado');
      await apply(tester);

      expect(find.text('No hay movimientos con estos filtros.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Cena'), findsOneWidget);
    });

    testWidgets('"Limpiar filtros" conserva la búsqueda en curso', (tester) async {
      await openList(tester, backendWith(data));
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mercado');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gastos'));
      await tester.pumpAndSettle();
      await apply(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(
        containerOf(tester).read(transactionFilterProvider).text,
        'mercado',
      );
    });

    testWidgets('al salir de la pantalla y volver, empieza sin filtros', (tester) async {
      await openList(tester, backendWith(data));
      await openFilterSheet(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      await apply(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await goTo(tester, AppRoutes.transactions);

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Cena'), findsOneWidget);
    });
  });

  group('estados', () {
    testWidgets('sin ningún movimiento invita a registrar el primero', (tester) async {
      await openList(tester, backendWith(const []));

      expect(find.text('Aún no registras movimientos.\nAnota el primero.'), findsOneWidget);
      expect(find.text('No hay movimientos con estos filtros.'), findsNothing);
    });

    testWidgets('si falla la carga muestra el error y permite reintentar', (tester) async {
      final backend = backendWith(many(3));
      backend.transactions.error = StateError('boom');
      await openList(tester, backend);

      expect(find.textContaining('No se pudo completar'), findsOneWidget);

      backend.transactions.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Compra 2'), findsOneWidget);
    });

    testWidgets('al registrar un movimiento la lista se recarga desde el principio', (
      tester,
    ) async {
      final backend = await openList(tester, backendWith(many(3)));

      expect(offsets(backend), [0]);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nuevo movimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5.000');
      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Bancolombia');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      // La lista se pidió otra vez desde la primera página y ya trae el nuevo.
      expect(offsets(backend), [0, 0]);
      expect(backend.transactions.created, hasLength(1));
      expect(find.text('Gasto'), findsOneWidget); // sin descripción ni categoría
    });
  });
}
