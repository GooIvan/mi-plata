import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

DateTime day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo);
}

void main() {
  setUpAll(initDates);

  group('dinero total', () {
    testWidgets('suma las cuentas activas, restando las deudas', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 1500000),
            testAccount('Efectivo', type: AccountType.cash, balance: 250000),
            testAccount('Visa', type: AccountType.card, balance: -350000),
            testAccount('Vieja', balance: 999999, archived: true),
          ],
        ),
      );

      expect(find.text('Dinero total'), findsOneWidget);
      // 1.500.000 + 250.000 - 350.000, sin contar la cuenta archivada.
      expect(textLike(r'$1.400.000'), findsOneWidget);
      expect(find.text('En 3 cuentas'), findsOneWidget);
    });

    testWidgets('con una sola cuenta lo dice en singular', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Nequi', balance: 80000)]),
      );

      expect(textLike(r'$80.000'), findsNWidgets(2)); // el total y la cuenta
      expect(find.text('En 1 cuenta'), findsOneWidget);
    });

    testWidgets('un total en contra se muestra con signo menos', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [testAccount('Visa', type: AccountType.card, balance: -100000)],
        ),
      );

      expect(textLike(r'-$100.000'), findsNWidgets(2));
    });

    testWidgets('suma los centavos sin errores de redondeo', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('A', balance: 0.1),
            testAccount('B', balance: 0.2),
          ],
        ),
      );

      expect(textLike(r'$0,30'), findsOneWidget);
    });

    testWidgets('sin cuentas invita a crear la primera', (tester) async {
      await pumpMiPlata(tester);

      expect(find.text('Aún no tienes cuentas'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);
    });

    testWidgets('si falla la carga ofrece reintentar', (tester) async {
      final backend = FakeBackend(accounts: [testAccount('Nequi', balance: 5000)]);
      backend.accounts.error = const PostgrestException(
        message: 'boom',
        code: '500',
      );
      await pumpMiPlata(tester, backend: backend);

      expect(find.text('No se pudo cargar tu dinero.'), findsOneWidget);

      backend.accounts.error = null;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar tu dinero.'), findsNothing);
      expect(textLike(r'$5.000'), findsNWidgets(2));
    });
  });

  group('cuentas', () {
    testWidgets('lista las activas con su saldo y oculta las archivadas', (
      tester,
    ) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(
          accounts: [
            testAccount('Bancolombia', balance: 1500000),
            testAccount('Vieja', balance: 10, archived: true),
          ],
        ),
      );

      expect(find.text('Bancolombia'), findsOneWidget);
      expect(find.text('Vieja'), findsNothing);
    });

    testWidgets('"Ver todas" lleva a la pantalla de cuentas', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Bancolombia')]),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Ver todas'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Cuentas'), findsOneWidget);
    });
  });

  group('últimos movimientos', () {
    FakeBackend backendWithSixMovements() => FakeBackend(
      accounts: [testAccount('Bancolombia', balance: 1000000)],
      categories: [testCategory('Mercado', CategoryType.expense)],
      transactions: [
        for (var i = 0; i < 6; i++)
          testTransaction(
            'tx-$i',
            type: TransactionType.expense,
            accountId: 'id-Bancolombia',
            categoryId: 'cat-Mercado',
            amount: 1000.0 * (i + 1),
            date: day(i),
            description: 'Compra $i',
          ),
      ],
    );

    testWidgets('muestra solo los cinco más recientes', (tester) async {
      await pumpMiPlata(tester, backend: backendWithSixMovements());

      // Los más recientes primero; el sexto (el más viejo) no aparece.
      expect(find.text('Compra 0'), findsOneWidget);
      expect(find.text('Compra 4'), findsOneWidget);
      expect(find.text('Compra 5'), findsNothing);
    });

    testWidgets('cada uno muestra su categoría, cuenta y monto con signo', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: backendWithSixMovements());

      expect(find.text('Mercado · Bancolombia'), findsNWidgets(5));
      expect(textLike(r'-$1.000'), findsOneWidget);
    });

    testWidgets('"Ver todos" lista todos, agrupados por día', (tester) async {
      await pumpMiPlata(tester, backend: backendWithSixMovements());

      await tester.tap(find.widgetWithText(TextButton, 'Ver todos'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ayer'), findsOneWidget);

      // La lista se construye bajo demanda: el más viejo está al final.
      await tester.scrollUntilVisible(find.text('Compra 5'), 200);
      expect(find.text('Compra 5'), findsOneWidget);
    });

    testWidgets('sin movimientos lo dice', (tester) async {
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Bancolombia')]),
      );

      expect(find.text('Aún no registras movimientos.'), findsOneWidget);
    });
  });

  testWidgets('registrar un gasto desde el panel actualiza el total', (
    tester,
  ) async {
    final backend = FakeBackend(
      accounts: [testAccount('Bancolombia', balance: 1000000)],
    );
    await pumpMiPlata(tester, backend: backend);
    expect(textLike(r'$1.000.000'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nuevo movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '120.000');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    expect(backend.transactions.created, hasLength(1));
    expect(textLike(r'$880.000'), findsNWidgets(2)); // total y cuenta
    expect(textLike(r'-$120.000'), findsOneWidget); // en últimos movimientos
  });
}
