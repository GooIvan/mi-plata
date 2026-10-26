import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/savings/domain/savings_goal.dart';
import 'package:mi_plata/features/savings/presentation/goal_detail_screen.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime inDays(int days) => DateTime(_now.year, _now.month, _now.day + days);

/// Dentro de un año, el mismo día: siempre son 12 meses justos.
DateTime inAYear() => DateTime(_now.year + 1, _now.month, _now.day);

SavingsGoal goal(
  String name, {
  double target = 5000000,
  String account = 'Ahorro viaje',
  DateTime? date,
  bool archived = false,
}) => SavingsGoal(
  id: 'goal-$name',
  name: name,
  targetCents: (target * 100).round(),
  accountId: 'id-$account',
  isArchived: archived,
  targetDate: date,
);

FakeBackend backend({List<SavingsGoal> goals = const []}) => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 3000000),
    testAccount('Ahorro viaje', balance: 1000000),
    testAccount('Fondo', balance: 200000),
    testAccount('Visa', type: AccountType.card, balance: -50000),
    testAccount('Vieja', balance: 1, archived: true),
  ],
  goals: goals,
);

Future<FakeBackend> open(
  WidgetTester tester,
  FakeBackend fakes, {
  String? route = AppRoutes.goals,
  String language = 'es',
}) async {
  tallView(tester);
  await pumpMiPlata(tester, backend: fakes, language: language);
  if (route != null) await goTo(tester, route);
  return fakes;
}

/// Abre el detalle de una meta tocándola en la lista.
Future<void> openDetail(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// El botón relleno con ícono: es una subclase de FilledButton.
Finder filled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<FilledButton>(),
);

Finder field(int index) => find.byType(TextFormField).at(index);
Finder accountDropdown() => find.byType(DropdownButtonFormField<String>);
Finder transferAccount(int index) =>
    find.byType(DropdownButtonFormField<String>).at(index);

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initDates);

  group('el panel', () {
    testWidgets('sin metas invita a crear la primera', (tester) async {
      await open(tester, backend(), route: null);

      expect(find.text('Metas de ahorro'), findsOneWidget);
      expect(
        find.text('Junta plata para algo: crea una meta de ahorro.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Junta plata para algo: crea una meta de ahorro.'),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Metas de ahorro'), findsOneWidget);
    });

    testWidgets('muestra las tres que vencen primero, sin las archivadas', (
      tester,
    ) async {
      await open(
        tester,
        backend(
          goals: [
            goal('Lejana', date: inDays(300), account: 'Bancolombia'),
            goal('Cercana', date: inDays(10), account: 'Ahorro viaje'),
            goal('Media', date: inDays(60), account: 'Fondo'),
            goal('Sin fecha', account: 'Vieja'),
            goal('Vieja meta', archived: true, date: inDays(1)),
          ],
        ),
        route: null,
      );

      expect(find.text('Cercana'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Lejana'), findsOneWidget);
      expect(find.text('Sin fecha'), findsNothing);
      expect(find.text('Vieja meta'), findsNothing);

      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Cercana'), lessThan(top('Media')));
      expect(top('Media'), lessThan(top('Lejana')));
    });

    testWidgets('tocar una meta abre su detalle', (tester) async {
      await open(
        tester,
        backend(goals: [goal('Viaje a Japón')]),
        route: null,
      );

      await openDetail(tester, 'Viaje a Japón');

      expect(find.widgetWithText(AppBar, 'Viaje a Japón'), findsOneWidget);
    });
  });

  group('la lista', () {
    testWidgets('sin metas explica qué es una y invita a crear', (tester) async {
      await open(tester, backend());

      expect(find.widgetWithText(AppBar, 'Metas de ahorro'), findsOneWidget);
      expect(find.textContaining('Una meta es una cantidad'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Crear meta'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Crear meta'), findsOneWidget);
    });

    testWidgets('cada meta dice cuánto lleva y cómo va', (tester) async {
      await open(
        tester,
        backend(
          goals: [
            goal('Viaje a Japón', date: inAYear()),
            goal('Fondo de emergencia', target: 200000, account: 'Fondo'),
            goal('Moto', account: 'Bancolombia', target: 9000000, date: inDays(-3)),
          ],
        ),
      );

      // 1.000.000 de 5.000.000.
      expect(textLike(r'$1.000.000 de $5.000.000'), findsOneWidget);
      expect(textLike('20 %'), findsOneWidget);
      expect(find.textContaining(r'Faltan $4.000.000 · quedan'), findsOneWidget);

      // Llegó a la meta.
      expect(find.text('¡Meta cumplida!'), findsOneWidget);
      expect(textLike('100 %'), findsOneWidget);

      // Pasó la fecha sin llegar.
      expect(find.textContaining('Venció el'), findsOneWidget);
      expect(find.textContaining(r'faltan $6.000.000'), findsOneWidget);
    });

    testWidgets('una meta sin fecha no habla de plazos', (tester) async {
      await open(tester, backend(goals: [goal('Viaje a Japón')]));

      expect(find.text(r'Faltan $4.000.000'), findsOneWidget);
      expect(find.textContaining('quedan'), findsNothing);
    });

    testWidgets('las que vencen antes van primero; las cumplidas, al final', (
      tester,
    ) async {
      await open(
        tester,
        backend(
          goals: [
            goal('Sin fecha', account: 'Bancolombia'),
            goal('Cumplida', target: 200000, account: 'Fondo', date: inDays(5)),
            goal('Pronto', date: inDays(20)),
          ],
        ),
      );

      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Pronto'), lessThan(top('Sin fecha')));
      expect(top('Sin fecha'), lessThan(top('Cumplida')));
    });

    testWidgets('las archivadas se piden con el botón', (tester) async {
      await open(
        tester,
        backend(
          goals: [
            goal('Viaje a Japón'),
            goal('Vieja meta', archived: true, account: 'Fondo'),
          ],
        ),
      );

      expect(find.text('Vieja meta'), findsNothing);

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();
      expect(find.text('Vieja meta'), findsOneWidget);
      expect(find.text('Archivada'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar archivadas'));
      await tester.pumpAndSettle();
      expect(find.text('Vieja meta'), findsNothing);
    });

    testWidgets('si todas están archivadas lo dice y ofrece mostrarlas', (
      tester,
    ) async {
      await open(
        tester,
        backend(goals: [goal('Vieja meta', archived: true)]),
      );

      expect(find.text('Todas tus metas están archivadas.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Mostrar archivadas'));
      await tester.pumpAndSettle();
      expect(find.text('Vieja meta'), findsOneWidget);
    });

    testWidgets('si no carga, avisa y se puede reintentar', (tester) async {
      final fakes = backend(goals: [goal('Viaje a Japón')]);
      fakes.goals.error = const PostgrestException(message: 'x', code: '500');
      await open(tester, fakes);

      expect(find.textContaining('No se pudo completar la operación'), findsOneWidget);

      fakes.goals.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje a Japón'), findsOneWidget);
    });
  });

  group('el formulario', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva meta'));
      await tester.pumpAndSettle();
    }

    testWidgets('crea una meta con su cuenta, monto y fecha', (tester) async {
      final fakes = await open(tester, backend());
      await openForm(tester);

      await tester.enterText(field(0), '  Viaje a Japón ');
      await pick(tester, accountDropdown(), 'Ahorro viaje');
      await tester.enterText(field(1), '5.000.000');
      await tester.tap(find.text('Sin fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pumpAndSettle();

      final created = fakes.goals.goals.single;
      expect(created.name, 'Viaje a Japón');
      expect(created.targetCents, 500000000);
      expect(created.accountId, 'id-Ahorro viaje');
      expect(created.targetDate, DateTime(_now.year, _now.month, _now.day));

      // Ya está en la lista, con lo que tiene la cuenta.
      expect(find.text('Viaje a Japón'), findsOneWidget);
      expect(textLike(r'$1.000.000 de $5.000.000'), findsOneWidget);
    });

    testWidgets('la fecha es opcional y se puede quitar', (tester) async {
      final fakes = await open(tester, backend());
      await openForm(tester);

      await tester.tap(find.text('Sin fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      expect(find.text('Sin fecha'), findsNothing);

      await tester.tap(find.byTooltip('Quitar la fecha'));
      await tester.pumpAndSettle();
      expect(find.text('Sin fecha'), findsOneWidget);

      await tester.enterText(field(0), 'Fondo');
      await pick(tester, accountDropdown(), 'Bancolombia');
      await tester.enterText(field(1), '100000');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pumpAndSettle();

      expect(fakes.goals.goals.single.targetDate, isNull);
    });

    testWidgets('pide nombre, monto y cuenta', (tester) async {
      final fakes = await open(tester, backend());
      await openForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pump();

      expect(find.text('Escribe el nombre de la meta'), findsOneWidget);
      expect(find.text('La meta tiene que ser mayor que cero'), findsOneWidget);
      expect(find.text('Elige la cuenta de la meta'), findsOneWidget);
      expect(fakes.goals.goals, isEmpty);
    });

    testWidgets('el monto tiene que ser mayor que cero', (tester) async {
      await open(tester, backend());
      await openForm(tester);

      await tester.enterText(field(1), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pump();
      expect(find.text('La meta tiene que ser mayor que cero'), findsOneWidget);

      await tester.enterText(field(1), 'mucho');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pump();
      expect(find.textContaining('Monto no válido'), findsOneWidget);
    });

    testWidgets(
      'solo ofrece cuentas donde se puede ahorrar: ni tarjetas, ni archivadas, ni las que ya tienen meta',
      (tester) async {
        await open(
          tester,
          backend(goals: [goal('Viaje a Japón', account: 'Ahorro viaje')]),
        );
        await openForm(tester);

        await tester.tap(accountDropdown());
        await tester.pumpAndSettle();

        expect(find.text('Bancolombia'), findsOneWidget);
        expect(find.text('Fondo'), findsOneWidget);
        expect(find.text('Ahorro viaje'), findsNothing);
        expect(find.text('Visa'), findsNothing);
        expect(find.text('Vieja (archivada)'), findsNothing);
      },
    );

    testWidgets('una meta archivada deja libre su cuenta', (tester) async {
      await open(
        tester,
        backend(goals: [goal('Vieja meta', archived: true)]),
      );
      await openForm(tester);

      await tester.tap(accountDropdown());
      await tester.pumpAndSettle();

      expect(find.text('Ahorro viaje'), findsOneWidget);
    });

    testWidgets('sin una cuenta libre lo explica y no deja crear', (tester) async {
      final fakes = FakeBackend(accounts: [testAccount('Visa', type: AccountType.card)]);
      await open(tester, fakes);
      await openForm(tester);

      expect(find.textContaining('No tienes una cuenta libre'), findsOneWidget);
      expect(accountDropdown(), findsNothing);

      await tester.enterText(field(0), 'Viaje');
      await tester.enterText(field(1), '1000');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pump();

      expect(find.text('Elige la cuenta de la meta'), findsOneWidget);
      expect(fakes.goals.goals, isEmpty);
    });

    testWidgets('se puede crear la cuenta ahí mismo y queda elegida', (
      tester,
    ) async {
      final fakes = await open(tester, backend());
      await openForm(tester);

      await tester.tap(find.text('Crear una cuenta nueva'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva cuenta'), findsOneWidget);

      final accountFields = find.descendant(
        of: find.byType(BottomSheet).last,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(accountFields.at(0), 'Alcancía');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      // De vuelta en la meta, la cuenta nueva ya está elegida.
      expect(find.text('Nueva cuenta'), findsNothing);
      expect(find.text('Alcancía'), findsOneWidget);

      await tester.enterText(field(0), 'Fondo de emergencia');
      await tester.enterText(field(1), '2000000');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pumpAndSettle();

      final created = fakes.goals.goals.single;
      expect(created.accountId, 'id-Alcancía');
      expect(textLike(r'$0 de $2.000.000'), findsOneWidget);
    });

    testWidgets('si el servidor dice que la cuenta ya tiene meta, avisa y queda abierto', (
      tester,
    ) async {
      final fakes = await open(tester, backend());
      await openForm(tester);

      await tester.enterText(field(0), 'Viaje');
      await pick(tester, accountDropdown(), 'Bancolombia');
      await tester.enterText(field(1), '1000');
      fakes.goals.error = const PostgrestException(
        message: 'duplicate key',
        code: '23505',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crear meta'));
      await tester.pumpAndSettle();

      expect(find.text('Esa cuenta ya tiene otra meta activa.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Crear meta'), findsOneWidget);
    });

    testWidgets('al editar se cambia el nombre, el monto y la fecha, no la cuenta', (
      tester,
    ) async {
      final fakes = await open(
        tester,
        backend(goals: [goal('Viaje a Japón', date: inDays(50))]),
      );
      await openDetail(tester, 'Viaje a Japón');

      await tester.tap(find.byTooltip('Editar meta'));
      await tester.pumpAndSettle();

      expect(find.text('Editar meta'), findsOneWidget);
      expect(find.text('La cuenta de una meta no se cambia.'), findsOneWidget);
      expect(accountDropdown(), findsNothing);
      expect(find.text('Crear una cuenta nueva'), findsNothing);
      expect(
        tester.widget<TextFormField>(field(0)).controller!.text,
        'Viaje a Japón',
      );
      expect(tester.widget<TextFormField>(field(1)).controller!.text, '5000000');

      await tester.enterText(field(0), 'Japón 2027');
      await tester.enterText(field(1), '6.000.000');
      await tester.tap(find.byTooltip('Quitar la fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final saved = fakes.goals.goals.single;
      expect(saved.name, 'Japón 2027');
      expect(saved.targetCents, 600000000);
      expect(saved.targetDate, isNull);
      expect(saved.accountId, 'id-Ahorro viaje');

      // El detalle ya muestra lo nuevo: 1.000.000 de 6.000.000 es 16 %.
      expect(find.widgetWithText(AppBar, 'Japón 2027'), findsOneWidget);
      expect(textLike(r'16 % de $6.000.000'), findsOneWidget);
    });
  });

  group('el detalle', () {
    testWidgets('dice cuánto lleva, cómo va y cuánto ahorrar al mes', (
      tester,
    ) async {
      await open(
        tester,
        backend(goals: [goal('Viaje a Japón', date: inAYear())]),
      );
      await openDetail(tester, 'Viaje a Japón');

      expect(find.widgetWithText(AppBar, 'Viaje a Japón'), findsOneWidget);
      expect(textLike(r'$1.000.000'), findsOneWidget);
      expect(textLike(r'20 % de $5.000.000'), findsOneWidget);
      expect(find.textContaining('Para el'), findsOneWidget);
      expect(find.textContaining(r'Faltan $4.000.000 · quedan'), findsOneWidget);
      // 4.000.000 en 12 meses: 333.333,33 se redondea hacia arriba.
      expect(
        find.text(r'Para llegar a tiempo, ahorra $333.334 al mes.'),
        findsOneWidget,
      );
      expect(find.text('Cuenta: Ahorro viaje'), findsOneWidget);
    });

    testWidgets('con menos de un mes, propone ahorrar todo lo que falta antes de la fecha', (
      tester,
    ) async {
      await open(
        tester,
        backend(goals: [goal('Viaje a Japón', date: inDays(10))]),
      );
      await openDetail(tester, 'Viaje a Japón');

      expect(
        find.textContaining(r'Para llegar a tiempo, ahorra $4.000.000 antes del'),
        findsOneWidget,
      );
      expect(find.textContaining('al mes'), findsNothing);
    });

    testWidgets('sin fecha no hay sugerencia', (tester) async {
      await open(tester, backend(goals: [goal('Viaje a Japón')]));
      await openDetail(tester, 'Viaje a Japón');

      expect(find.textContaining('Para llegar a tiempo'), findsNothing);
      expect(find.textContaining('Para el'), findsNothing);
    });

    testWidgets('una meta cumplida lo celebra y sugiere archivarla', (tester) async {
      await open(
        tester,
        backend(goals: [goal('Fondo de emergencia', target: 150000, account: 'Fondo')]),
      );
      await openDetail(tester, 'Fondo de emergencia');

      expect(find.text('¡Meta cumplida!'), findsOneWidget);
      expect(
        find.text('Cuando ya no la necesites, archívala para liberar su cuenta.'),
        findsOneWidget,
      );
      expect(find.textContaining('Para llegar a tiempo'), findsNothing);
    });

    testWidgets('una meta vencida dice cuánto faltó', (tester) async {
      await open(
        tester,
        backend(goals: [goal('Moto', date: inDays(-3))]),
      );
      await openDetail(tester, 'Moto');

      expect(find.textContaining('Venció el'), findsOneWidget);
      expect(find.textContaining(r'faltan $4.000.000'), findsOneWidget);
      expect(find.textContaining('Para llegar a tiempo'), findsNothing);
    });

    testWidgets('los movimientos de la cuenta, con lo que entró y lo que salió', (
      tester,
    ) async {
      final fakes = FakeBackend(
        accounts: [
          testAccount('Bancolombia', balance: 3000000),
          testAccount('Ahorro viaje', balance: 0),
        ],
        goals: [goal('Viaje a Japón')],
        transactions: [
          testTransaction(
            't1',
            type: TransactionType.transfer,
            accountId: 'id-Bancolombia',
            destinationAccountId: 'id-Ahorro viaje',
            amount: 800000,
            date: inDays(-5),
          ),
          testTransaction(
            't2',
            type: TransactionType.income,
            accountId: 'id-Ahorro viaje',
            amount: 150000,
            date: inDays(-3),
            description: 'Prima',
          ),
          testTransaction(
            't3',
            type: TransactionType.transfer,
            accountId: 'id-Ahorro viaje',
            destinationAccountId: 'id-Bancolombia',
            amount: 50000,
            date: inDays(-1),
          ),
        ],
      );
      await open(tester, fakes);
      await openDetail(tester, 'Viaje a Japón');

      expect(find.text('Movimientos de la meta'), findsOneWidget);
      expect(textLike(r'+$800.000'), findsOneWidget);
      expect(find.text('Desde Bancolombia'), findsOneWidget);
      expect(textLike(r'+$150.000'), findsOneWidget);
      expect(find.text('Prima'), findsOneWidget);
      expect(textLike(r'−$50.000'), findsOneWidget);
      expect(find.text('Hacia Bancolombia'), findsOneWidget);

      // 800.000 + 150.000 - 50.000.
      expect(textLike(r'$900.000'), findsOneWidget);
    });

    testWidgets('sin movimientos lo dice', (tester) async {
      final fakes = FakeBackend(
        accounts: [testAccount('Ahorro viaje')],
        goals: [goal('Viaje a Japón')],
      );
      await open(tester, fakes);
      await openDetail(tester, 'Viaje a Japón');

      expect(
        find.text('Todavía no has ahorrado nada en esta cuenta.'),
        findsOneWidget,
      );
    });

    testWidgets('una meta que ya no existe lo dice', (tester) async {
      await open(tester, backend(goals: [goal('Viaje a Japón')]));

      Navigator.of(tester.element(find.byType(Scaffold).last)).push(
        MaterialPageRoute<void>(
          builder: (_) => const GoalDetailScreen(goalId: 'goal-borrada'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esta meta ya no existe.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje a Japón'), findsOneWidget);
    });
  });

  group('ahorrar y sacar', () {
    testWidgets('"Ahorrar" abre una transferencia hacia la cuenta de la meta', (
      tester,
    ) async {
      final fakes = await open(tester, backend(goals: [goal('Viaje a Japón')]));
      await openDetail(tester, 'Viaje a Japón');

      await tester.tap(filled('Ahorrar'));
      await tester.pumpAndSettle();

      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hacia'), findsOneWidget);
      // El destino ya viene elegido; el origen, no (hay varias cuentas).
      expect(
        find.descendant(
          of: transferAccount(1),
          matching: find.text('Ahorro viaje'),
        ),
        findsOneWidget,
      );

      await pick(tester, transferAccount(0), 'Bancolombia');
      await tester.enterText(find.byType(TextFormField).at(0), '500000');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      final draft = fakes.transactions.created.single;
      expect(draft.type, TransactionType.transfer);
      expect(draft.accountId, 'id-Bancolombia');
      expect(draft.destinationAccountId, 'id-Ahorro viaje');

      // El avance sube con la transferencia: 1.500.000 de 5.000.000.
      expect(textLike(r'$1.500.000'), findsOneWidget);
      expect(textLike(r'30 % de $5.000.000'), findsOneWidget);
      expect(textLike(r'+$500.000'), findsOneWidget);
    });

    testWidgets('con una sola cuenta más, el origen ya viene elegido', (
      tester,
    ) async {
      final fakes = FakeBackend(
        accounts: [
          testAccount('Bancolombia', balance: 3000000),
          testAccount('Ahorro viaje', balance: 1000000),
        ],
        goals: [goal('Viaje a Japón')],
      );
      await open(tester, fakes);
      await openDetail(tester, 'Viaje a Japón');

      await tester.tap(filled('Ahorrar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '250000');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      final draft = fakes.transactions.created.single;
      expect(draft.accountId, 'id-Bancolombia');
      expect(draft.destinationAccountId, 'id-Ahorro viaje');
      expect(textLike(r'25 % de $5.000.000'), findsOneWidget);
    });

    testWidgets('"Sacar" abre una transferencia desde la cuenta de la meta', (
      tester,
    ) async {
      final fakes = await open(tester, backend(goals: [goal('Viaje a Japón')]));
      await openDetail(tester, 'Viaje a Japón');

      await tester.tap(find.text('Sacar'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: transferAccount(0),
          matching: find.text('Ahorro viaje'),
        ),
        findsOneWidget,
      );

      await pick(tester, transferAccount(1), 'Bancolombia');
      await tester.enterText(find.byType(TextFormField).at(0), '400000');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      final draft = fakes.transactions.created.single;
      expect(draft.accountId, 'id-Ahorro viaje');
      expect(draft.destinationAccountId, 'id-Bancolombia');
      expect(textLike(r'12 % de $5.000.000'), findsOneWidget);
      expect(textLike(r'−$400.000'), findsOneWidget);
    });

    testWidgets('si la cuenta se archivó, avisa y no deja mover plata', (
      tester,
    ) async {
      await open(
        tester,
        backend(goals: [goal('Viaje a Japón', account: 'Vieja')]),
      );
      await openDetail(tester, 'Viaje a Japón');

      expect(
        find.text('La cuenta Vieja está archivada: ya no puedes ahorrar en ella.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(filled('Ahorrar')).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Sacar'),
            matching: find.bySubtype<OutlinedButton>(),
          ),
        ).onPressed,
        isNull,
      );
    });
  });

  group('archivar', () {
    Future<void> menu(WidgetTester tester, String option) async {
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('archiva y restaura una meta', (tester) async {
      final fakes = await open(tester, backend(goals: [goal('Viaje a Japón')]));
      await openDetail(tester, 'Viaje a Japón');

      await menu(tester, 'Archivar');
      expect(find.text('Meta archivada'), findsOneWidget);
      expect(fakes.goals.goals.single.isArchived, isTrue);
      expect(find.text('Archivada'), findsOneWidget);
      // Archivada, ya no se ahorra en ella.
      expect(find.text('Ahorrar'), findsNothing);
      expect(find.text('Sacar'), findsNothing);

      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await menu(tester, 'Restaurar');
      expect(find.text('Meta restaurada'), findsOneWidget);
      expect(fakes.goals.goals.single.isArchived, isFalse);
      expect(find.text('Ahorrar'), findsOneWidget);
    });

    testWidgets('no se restaura si su cuenta ya tiene otra meta', (tester) async {
      final fakes = await open(
        tester,
        backend(
          goals: [
            goal('Vieja meta', archived: true),
            goal('Nueva meta'),
          ],
        ),
      );
      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();
      await openDetail(tester, 'Vieja meta');

      await menu(tester, 'Restaurar');

      expect(find.text('Esa cuenta ya tiene otra meta activa.'), findsOneWidget);
      expect(
        fakes.goals.goals.firstWhere((g) => g.name == 'Vieja meta').isArchived,
        isTrue,
      );
    });
  });

  group('en inglés', () {
    testWidgets('el panel, la lista, el formulario y el detalle', (tester) async {
      await open(
        tester,
        backend(goals: [goal('Japan trip', date: inAYear())]),
        language: 'en',
        route: null,
      );

      expect(find.text('Savings goals'), findsOneWidget);
      await goTo(tester, AppRoutes.goals);
      expect(find.widgetWithText(AppBar, 'Savings goals'), findsOneWidget);
      expect(textLike(r'$1,000,000 of $5,000,000'), findsOneWidget);
      expect(find.textContaining(r'$4,000,000 to go · '), findsOneWidget);
      expect(find.textContaining('days left'), findsOneWidget);

      await openDetail(tester, 'Japan trip');
      expect(textLike(r'20% of $5,000,000'), findsOneWidget);
      expect(find.text('Account: Ahorro viaje'), findsOneWidget);
      expect(
        find.text(r'To get there on time, save $333,334 a month.'),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Goal activity'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit goal'));
      await tester.pumpAndSettle();
      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text("A goal's account can't be changed."), findsOneWidget);
    });

    testWidgets('sin metas, el estado vacío y el formulario nuevo', (tester) async {
      await open(tester, backend(), language: 'en');

      expect(find.textContaining('A goal is an amount you want to save up'), findsOneWidget);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New goal'));
      await tester.pumpAndSettle();
      expect(find.text('How much do you want to save'), findsOneWidget);
      expect(find.text('Deadline (optional)'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
      expect(find.text('Create a new account'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Create goal'));
      await tester.pump();
      expect(find.text("Enter the goal's name"), findsOneWidget);
      expect(find.text('The goal must be greater than zero'), findsOneWidget);
      expect(find.text("Choose the goal's account"), findsOneWidget);
    });
  });
}
