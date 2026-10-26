import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/savings/domain/savings_goal.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

Finder tab(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

FakeBackend backend() => FakeBackend(
  accounts: [testAccount('Bancolombia', balance: 1000000)],
);

FakeBackend withGoal() => FakeBackend(
  accounts: [testAccount('Ahorro', balance: 100000)],
  goals: [
    const SavingsGoal(
      id: 'g1',
      name: 'Viaje',
      targetCents: 100000000,
      accountId: 'id-Ahorro',
      isArchived: false,
    ),
  ],
);

void main() {
  setUpAll(initDates);

  testWidgets('la barra tiene las cinco pestañas, con Inicio elegida', (tester) async {
    await pumpMiPlata(tester, backend: backend());

    for (final label in ['Inicio', 'Actividad', 'Cuentas', 'Metas', 'Más']) {
      expect(tab(label), findsOneWidget, reason: label);
    }
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.text('mi-plata'), findsOneWidget);
  });

  testWidgets('cada pestaña abre su pantalla y la marca como elegida', (tester) async {
    await pumpMiPlata(tester, backend: backend());

    final screens = {
      'Actividad': (1, find.widgetWithText(AppBar, 'Movimientos')),
      'Cuentas': (2, find.widgetWithText(AppBar, 'Cuentas')),
      'Metas': (3, find.widgetWithText(AppBar, 'Metas de ahorro')),
      'Más': (4, find.widgetWithText(AppBar, 'Más')),
    };
    for (final entry in screens.entries) {
      await tester.tap(tab(entry.key));
      await tester.pumpAndSettle();

      expect(entry.value.$2, findsOneWidget, reason: entry.key);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        entry.value.$1,
        reason: entry.key,
      );
    }

    await tester.tap(tab('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('mi-plata'), findsOneWidget);
  });

  testWidgets('las pestañas no tienen flecha de volver', (tester) async {
    await pumpMiPlata(tester, backend: backend());

    for (final label in ['Actividad', 'Cuentas', 'Metas', 'Más']) {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing, reason: label);
    }
  });

  group('Más', () {
    testWidgets('reúne lo que no cabe en la barra', (tester) async {
      await pumpMiPlata(tester, backend: backend());
      await tester.tap(tab('Más'));
      await tester.pumpAndSettle();

      for (final entry in [
        'Resumen mensual',
        'Presupuestos',
        'Deudas',
        'Pagos recurrentes',
        'Categorías',
        'Ajustes',
      ]) {
        expect(find.widgetWithText(ListTile, entry), findsOneWidget, reason: entry);
      }
    });

    testWidgets('cada entrada abre su pantalla a pantalla completa y se vuelve a Más', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: backend());

      for (final (entry, title) in [
        ('Resumen mensual', 'Resumen mensual'),
        ('Presupuestos', 'Presupuestos'),
        ('Deudas', 'Deudas'),
        ('Pagos recurrentes', 'Pagos recurrentes'),
        ('Categorías', 'Categorías'),
        ('Ajustes', 'Ajustes'),
      ]) {
        await openFromMore(tester, entry);
        expect(find.widgetWithText(AppBar, title), findsOneWidget, reason: entry);
        // La pantalla cubre la barra: no se puede cambiar de pestaña por debajo.
        expect(find.byType(NavigationBar), findsNothing, reason: entry);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Más'), findsOneWidget, reason: entry);
        expect(find.byType(NavigationBar), findsOneWidget);
      }
    });
  });

  group('estado de cada pestaña', () {
    testWidgets('una pestaña conserva lo que estabas viendo al cambiar y volver', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: backend());
      await tester.tap(tab('Cuentas'));
      await tester.pumpAndSettle();

      // Abre la hoja de una cuenta, ciérrala y cambia de pestaña.
      await tester.tap(tab('Metas'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Cuentas'));
      await tester.pumpAndSettle();

      expect(find.text('Bancolombia'), findsOneWidget);
    });

    testWidgets('el detalle de una meta deja la barra a la vista; tocar su pestaña vuelve a la lista', (
      tester,
    ) async {
      await pumpMiPlata(tester, backend: withGoal());
      await tester.tap(tab('Metas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Viaje'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Viaje'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(tab('Metas'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Metas de ahorro'), findsOneWidget);
    });

    testWidgets('el detalle sigue ahí si cambias de pestaña y vuelves', (tester) async {
      await pumpMiPlata(tester, backend: withGoal());
      await tester.tap(tab('Metas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viaje'));
      await tester.pumpAndSettle();

      await tester.tap(tab('Cuentas'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Metas'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Viaje'), findsOneWidget);
    });
  });

  group('la barra no estorba', () {
    testWidgets('el formulario de movimientos cubre la barra', (tester) async {
      await pumpMiPlata(tester, backend: backend());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nuevo movimiento'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Nuevo movimiento'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('las hojas de formulario cubren la barra', (tester) async {
      await pumpMiPlata(tester, backend: backend());
      await tester.tap(tab('Cuentas'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva cuenta'));
      await tester.pumpAndSettle();

      // La hoja llega hasta el borde de abajo, por encima de la barra.
      expect(find.text('Saldo inicial'), findsOneWidget);
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(find.byType(BottomSheet)).dy, screen);
      final bar = tester.getTopLeft(find.byType(NavigationBar)).dy;
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, lessThan(bar));
    });
  });

  testWidgets('en inglés, la barra y Más salen en inglés', (tester) async {
    await pumpMiPlata(tester, backend: backend(), language: 'en');

    for (final label in ['Home', 'Activity', 'Accounts', 'Goals', 'More']) {
      expect(tab(label), findsOneWidget, reason: label);
    }
    await tester.tap(tab('More'));
    await tester.pumpAndSettle();
    for (final entry in [
      'Monthly summary',
      'Budgets',
      'Debts',
      'Recurring payments',
      'Categories',
      'Settings',
    ]) {
      expect(find.widgetWithText(ListTile, entry), findsOneWidget, reason: entry);
    }
  });

  testWidgets('sin sesión no hay barra', (tester) async {
    await pumpMiPlata(tester, auth: FakeAuthRepository());

    expect(find.byType(NavigationBar), findsNothing);
  });
}
