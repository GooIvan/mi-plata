import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

const _receivable = DebtDirection.receivable;

final _now = DateTime.now();
DateTime inDays(int days) => DateTime(_now.year, _now.month, _now.day + days);

/// Dos cuentas y cinco deudas:
/// - Juan (debo 500.000, ya abonó 200.000, vence en 3 días)
/// - Pedro (debo 80.000, vencida hace 5 días)
/// - Carlos (debo 100.000, saldada)
/// - María (me debe 300.000, ya abonó 50.000, sin fecha)
/// - Vieja (archivada)
///
/// Los abonos salen/entran de Bancolombia: 1.000.000 - 200.000 - 100.000
/// + 50.000 = 750.000.
class Fixture {
  Fixture()
    : backend = FakeBackend(
        accounts: [
          testAccount('Bancolombia', balance: 1000000),
          testAccount('Nequi', type: AccountType.wallet, balance: 50000),
        ],
      ) {
    backend.debts
      ..seedDebt(counterparty: 'Juan', amount: 500000, payments: [200000], dueDate: inDays(3))
      ..seedDebt(counterparty: 'Pedro', amount: 80000, dueDate: inDays(-5))
      ..seedDebt(counterparty: 'Carlos', amount: 100000, payments: [100000])
      ..seedDebt(
        direction: _receivable,
        counterparty: 'María',
        amount: 300000,
        payments: [50000],
      )
      ..seedDebt(counterparty: 'Vieja', amount: 10000, archived: true);
  }

  final FakeBackend backend;
}

Future<void> tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeBackend> openDebts(WidgetTester tester, [FakeBackend? backend]) async {
  await tall(tester);
  final fakes = backend ?? Fixture().backend;
  await pumpMiPlata(tester, backend: fakes);
  await goTo(tester, AppRoutes.debts);
  return fakes;
}

Finder tab(String label) => find.widgetWithText(Tab, label);
Finder newDebtButton() => find.widgetWithText(FloatingActionButton, 'Nueva deuda');
Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);
Finder dropdown() => find.byType(DropdownButtonFormField<String>);

Future<void> pick(WidgetTester tester, Finder from, String option) async {
  await tester.tap(from);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> openDebt(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

double balanceOf(List<dynamic> accounts, String name) =>
    accounts.firstWhere((a) => a.name == name).currentBalance as double;

void main() {
  setUpAll(initDates);

  group('lista', () {
    testWidgets('"Debo" muestra lo pendiente y el total, sin archivadas', (tester) async {
      await openDebts(tester);

      expect(find.widgetWithText(AppBar, 'Deudas'), findsOneWidget);
      expect(find.text('Debes en total'), findsOneWidget);
      // Juan 300.000 + Pedro 80.000; Carlos está saldada y Vieja archivada.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: textLike(r'$380.000'),
        ),
        findsOneWidget,
      );
      expect(find.text('Juan'), findsOneWidget);
      expect(find.text('Pedro'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('Vieja'), findsNothing);
      expect(find.text('María'), findsNothing);
    });

    testWidgets('lo vencido va primero y lo saldado al final', (tester) async {
      await openDebts(tester);

      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Pedro'), lessThan(top('Juan')));
      expect(top('Juan'), lessThan(top('Carlos')));
    });

    testWidgets('cada una dice cómo está: vencida, por vencer, saldada', (tester) async {
      await openDebts(tester);

      expect(find.text('Vencida hace 5 días'), findsOneWidget);
      expect(find.text('Vence en 3 días'), findsOneWidget);
      expect(find.text('Saldada'), findsOneWidget);
      // El pendiente y el avance de cada una.
      expect(textLike(r'$300.000'), findsWidgets); // Juan
      expect(find.text('de \$500.000'), findsOneWidget);
    });

    testWidgets('"Me deben" muestra lo que te deben', (tester) async {
      await openDebts(tester);

      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();

      expect(find.text('Te deben en total'), findsOneWidget);
      expect(find.text('María'), findsOneWidget);
      expect(find.text('Sin fecha de vencimiento'), findsOneWidget);
      expect(find.text('Juan'), findsNothing);
    });

    testWidgets('las archivadas se ocultan y se pueden mostrar', (tester) async {
      await openDebts(tester);

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();

      expect(find.text('Vieja'), findsOneWidget);
    });

    testWidgets('sin deudas de un sentido lo dice y ofrece registrar', (tester) async {
      final backend = FakeBackend(accounts: [testAccount('Bancolombia')]);
      await openDebts(tester, backend);

      expect(find.text('Aún no registras deudas que debas.'), findsOneWidget);
      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no registras deudas que te deban.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Registrar deuda'), findsOneWidget);
    });

    testWidgets('si falla la carga muestra el error y permite reintentar', (tester) async {
      final fixture = Fixture();
      fixture.backend.debts.error = const PostgrestException(message: 'boom', code: '500');
      await openDebts(tester, fixture.backend);

      expect(find.textContaining('No se pudo completar'), findsOneWidget);

      fixture.backend.debts.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Juan'), findsOneWidget);
    });
  });

  group('crear', () {
    Future<void> fill(
      WidgetTester tester, {
      String who = 'Luis',
      String amount = '250.000',
    }) async {
      await tester.enterText(field(0), who);
      await tester.enterText(field(1), amount);
    }

    testWidgets('en "Debo" crea una deuda que debes, sin tocar las cuentas', (
      tester,
    ) async {
      final backend = await openDebts(tester);
      final before = await backend.accounts.fetchAll();

      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Nueva deuda'), findsOneWidget);
      await fill(tester);
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(backend.debts.calls, contains('create:payable:Luis:250000:null'));
      expect(find.text('Luis'), findsOneWidget);
      final after = await backend.accounts.fetchAll();
      expect(balanceOf(after, 'Bancolombia'), balanceOf(before, 'Bancolombia'));
    });

    testWidgets('desde "Me deben" el sentido ya viene elegido', (tester) async {
      final backend = await openDebts(tester);

      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();
      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      expect(find.text('Quién te debe'), findsOneWidget);
      await fill(tester, who: 'Ana', amount: '100.000');
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(backend.debts.calls, contains('create:receivable:Ana:100000:null'));
    });

    testWidgets('el selector de sentido cambia las etiquetas', (tester) async {
      await openDebts(tester);
      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      expect(find.text('A quién le debes'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<DebtDirection>),
          matching: find.text('Me deben'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quién te debe'), findsOneWidget);
    });

    testWidgets('registrar el dinero de un préstamo recibido lo mete a la cuenta', (
      tester,
    ) async {
      final backend = await openDebts(tester);
      final before = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');

      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('El dinero que te prestaron entra a la cuenta.'), findsOneWidget);
      await pick(tester, dropdown(), 'Bancolombia');
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(backend.debts.calls, contains('create:payable:Luis:250000:id-Bancolombia'));
      final after = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');
      expect(after, before + 250000);
    });

    testWidgets('prestar dinero que no alcanza avisa antes de registrarlo', (
      tester,
    ) async {
      final backend = await openDebts(tester);

      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();
      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      await fill(tester, who: 'Ana', amount: '100.000');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('El dinero que prestaste sale de la cuenta.'), findsOneWidget);
      await pick(tester, dropdown(), 'Nequi'); // tiene 50.000

      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();
      expect(find.text('¿Registrar de todos modos?'), findsOneWidget);
      expect(find.textContaining(r'Nequi quedará en -$50.000.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Corregir'));
      await tester.pumpAndSettle();
      expect(backend.debts.calls.where((c) => c.startsWith('create')), isEmpty);

      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar igual'));
      await tester.pumpAndSettle();
      expect(backend.debts.calls, contains('create:receivable:Ana:100000:id-Nequi'));
    });

    testWidgets('exige la persona y el monto sin llamar al servidor', (tester) async {
      final backend = await openDebts(tester);

      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      await tester.tap(button('Crear deuda'));
      await tester.pump();

      expect(find.text('Escribe el nombre de la persona'), findsOneWidget);
      expect(find.text('Ingresa el monto'), findsOneWidget);
      expect(backend.debts.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('si el servidor falla avisa y deja el formulario abierto', (
      tester,
    ) async {
      final backend = await openDebts(tester);
      backend.debts.error = const PostgrestException(message: 'boom', code: '500');

      await tester.tap(newDebtButton());
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo completar'), findsOneWidget);
      expect(button('Crear deuda'), findsOneWidget);
    });
  });

  group('detalle', () {
    testWidgets('muestra lo pagado, lo pendiente y sus abonos', (tester) async {
      await openDebts(tester);
      await openDebt(tester, 'Juan');

      expect(find.text('Le debes a Juan'), findsOneWidget);
      expect(find.text('pendiente'), findsOneWidget);
      expect(find.text(r'Pagado $200.000'), findsOneWidget);
      expect(find.text(r'Total $500.000'), findsOneWidget);
      expect(find.text('Vence en 3 días'), findsOneWidget);
      expect(find.text('Abonos'), findsOneWidget);
      // Un abono de 200.000 desde Bancolombia.
      expect(find.textContaining('Bancolombia'), findsWidgets);
      expect(textLike(r'$200.000'), findsWidgets);
    });

    testWidgets('para una deuda que me deben habla de cobrar', (tester) async {
      await openDebts(tester);
      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();
      await openDebt(tester, 'María');

      expect(find.text('María te debe'), findsOneWidget);
    });

    testWidgets('una deuda saldada no deja registrar más abonos', (tester) async {
      await openDebts(tester);
      await openDebt(tester, 'Carlos');

      final register = tester.widget<FilledButton>(button('Registrar abono'));
      expect(register.onPressed, isNull);
      expect(find.text('Esta deuda ya está saldada.'), findsOneWidget);
    });
  });

  group('abonos', () {
    Future<void> openPayment(WidgetTester tester) async {
      await openDebt(tester, 'Juan');
      await tester.tap(button('Registrar abono'));
      await tester.pumpAndSettle();
    }

    testWidgets('un abono baja lo pendiente y mueve la cuenta', (tester) async {
      final backend = await openDebts(tester);
      final before = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');
      await openPayment(tester);

      expect(find.text('Abonar a Juan'), findsOneWidget);
      expect(find.text(r'Pendiente: $300.000'), findsOneWidget);
      await tester.enterText(field(0), '100.000');
      await pick(tester, dropdown(), 'Bancolombia');
      await tester.tap(button('Registrar abono').last);
      await tester.pumpAndSettle();

      expect(
        backend.debts.calls,
        contains('registerPayment:debt-1:id-Bancolombia:100000'),
      );
      expect(find.text(r'Pagado $300.000'), findsOneWidget);
      final after = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');
      expect(after, before - 100000); // pagar es un gasto
    });

    testWidgets('"Pagar todo" llena lo que falta', (tester) async {
      await openDebts(tester);
      await openPayment(tester);

      await tester.tap(find.text('Pagar todo'));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, '300000'), findsOneWidget);
    });

    testWidgets('un abono mayor a lo pendiente no se envía', (tester) async {
      final backend = await openDebts(tester);
      await openPayment(tester);

      await tester.enterText(field(0), '300.001');
      await pick(tester, dropdown(), 'Bancolombia');
      await tester.tap(button('Registrar abono').last);
      await tester.pump();

      expect(find.text(r'No puede superar lo pendiente ($300.000)'), findsOneWidget);
      expect(
        backend.debts.calls.where((c) => c.startsWith('registerPayment')),
        isEmpty,
      );
    });

    testWidgets('pagar desde una cuenta sin saldo avisa antes', (tester) async {
      final backend = await openDebts(tester);
      await openPayment(tester);

      await tester.enterText(field(0), '100.000');
      await pick(tester, dropdown(), 'Nequi'); // tiene 50.000
      await tester.tap(button('Registrar abono').last);
      await tester.pumpAndSettle();

      expect(find.textContaining(r'Nequi quedará en -$50.000.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Corregir'));
      await tester.pumpAndSettle();
      expect(
        backend.debts.calls.where((c) => c.startsWith('registerPayment')),
        isEmpty,
      );

      await tester.tap(button('Registrar abono').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar igual'));
      await tester.pumpAndSettle();
      expect(
        backend.debts.calls,
        contains('registerPayment:debt-1:id-Nequi:100000'),
      );
    });

    testWidgets('cobrar un abono es un ingreso y no avisa de saldo', (tester) async {
      final backend = await openDebts(tester);
      final before = balanceOf(await backend.accounts.fetchAll(), 'Nequi');
      await tester.tap(tab('Me deben'));
      await tester.pumpAndSettle();
      await openDebt(tester, 'María');
      await tester.tap(button('Registrar abono'));
      await tester.pumpAndSettle();

      // Es el título de la hoja y también la sugerencia del campo descripción.
      expect(find.text('Abono de María'), findsNWidgets(2));
      await tester.enterText(field(0), '100.000');
      await pick(tester, dropdown(), 'Nequi');
      await tester.tap(button('Registrar abono').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final after = balanceOf(await backend.accounts.fetchAll(), 'Nequi');
      expect(after, before + 100000);
    });

    testWidgets('eliminar un abono devuelve el dinero y lo pendiente', (tester) async {
      final backend = await openDebts(tester);
      final before = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');
      await openDebt(tester, 'Juan');

      await tester.tap(find.byTooltip('Eliminar abono'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este abono?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Abono eliminado'), findsOneWidget);
      expect(find.text('Aún no hay abonos.'), findsOneWidget);
      expect(find.text(r'Pagado $0'), findsOneWidget);
      final after = balanceOf(await backend.accounts.fetchAll(), 'Bancolombia');
      expect(after, before + 200000);
    });

    testWidgets('cancelar al eliminar no borra nada', (tester) async {
      await openDebts(tester);
      await openDebt(tester, 'Juan');

      await tester.tap(find.byTooltip('Eliminar abono'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text(r'Pagado $200.000'), findsOneWidget);
    });
  });

  group('editar y archivar', () {
    testWidgets('editar precarga los datos y guarda los cambios', (tester) async {
      final backend = await openDebts(tester);
      await openDebt(tester, 'Juan');

      await tester.tap(find.byTooltip('Editar deuda'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Editar deuda'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Juan'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '500000'), findsOneWidget);

      await tester.enterText(field(0), 'Juan Pérez');
      await tester.enterText(field(1), '600.000');
      await tester.tap(button('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(backend.debts.calls, contains('update:debt-1:Juan Pérez:600000'));
      expect(find.text('Le debes a Juan Pérez'), findsOneWidget);
      expect(find.text(r'Total $600.000'), findsOneWidget);
    });

    testWidgets('el monto no puede bajar de lo ya pagado', (tester) async {
      final backend = await openDebts(tester);
      await openDebt(tester, 'Juan');
      await tester.tap(find.byTooltip('Editar deuda'));
      await tester.pumpAndSettle();

      await tester.enterText(field(1), '150.000'); // ya pagó 200.000
      await tester.tap(button('Guardar cambios'));
      await tester.pump();

      expect(
        find.text(r'No puede ser menor a lo ya pagado ($200.000)'),
        findsOneWidget,
      );
      expect(backend.debts.calls.where((c) => c.startsWith('update')), isEmpty);
    });

    testWidgets('al editar, el sentido no se puede cambiar', (tester) async {
      await openDebts(tester);
      await openDebt(tester, 'Juan');
      await tester.tap(find.byTooltip('Editar deuda'));
      await tester.pumpAndSettle();

      final selector = tester.widget<SegmentedButton<DebtDirection>>(
        find.byType(SegmentedButton<DebtDirection>),
      );
      expect(selector.onSelectionChanged, isNull);
      // Ni se ofrece registrar el dinero de nuevo.
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('archivar deja la deuda sin abonos nuevos, y se puede deshacer', (
      tester,
    ) async {
      final backend = await openDebts(tester);
      await openDebt(tester, 'Juan');

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();

      expect(find.text('Deuda archivada'), findsOneWidget);
      expect(find.text('Está archivada: restáurala para registrar abonos.'), findsOneWidget);
      expect(tester.widget<FilledButton>(button('Registrar abono')).onPressed, isNull);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button('Registrar abono')).onPressed, isNotNull);
      expect(backend.debts.calls, containsAll(['setArchived:debt-1:true', 'setArchived:debt-1:false']));
    });
  });

  group('panel principal', () {
    testWidgets('la tarjeta muestra lo que debes y lo que te deben', (tester) async {
      await tall(tester);
      await pumpMiPlata(tester, backend: Fixture().backend);

      expect(find.text('Deudas'), findsOneWidget);
      expect(find.text('Debes'), findsOneWidget);
      expect(find.text('Te deben'), findsOneWidget);
      expect(textLike(r'$380.000'), findsOneWidget);
      expect(textLike(r'$250.000'), findsOneWidget);
    });

    testWidgets('al tocarla abre las deudas', (tester) async {
      await tall(tester);
      await pumpMiPlata(tester, backend: Fixture().backend);

      await tester.tap(find.text('Debes'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Deudas'), findsOneWidget);
    });

    testWidgets('sin deudas invita a registrarlas', (tester) async {
      await tall(tester);
      await pumpMiPlata(
        tester,
        backend: FakeBackend(accounts: [testAccount('Bancolombia')]),
      );

      expect(find.text('Registra lo que debes o te deben'), findsOneWidget);
    });
  });
}
