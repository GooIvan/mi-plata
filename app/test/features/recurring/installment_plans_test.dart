import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime inDays(int days) => DateTime(_now.year, _now.month, _now.day + days);

FakeBackend backend() => FakeBackend(
  accounts: [
    // Con saldo de sobra: los abonos que ya se hicieron también restan.
    testAccount('Bancolombia', balance: 10000000),
    testAccount('Dólares', balance: 500, currency: 'USD'),
  ],
  categories: [
    testCategory('Hogar', CategoryType.expense),
    testCategory('Salario', CategoryType.income),
  ],
);

/// Una compra a cuotas ya hecha: la deuda y su plan.
String seedPlan(
  FakeBackend fakes, {
  String name = 'TV Samsung',
  double total = 2400000,
  double installment = 200000,
  int installments = 12,
  List<double> payments = const [],
  DateTime? next,
  String account = 'id-Bancolombia',
  String currency = 'COP',
  String? categoryId,
}) {
  final debtId = fakes.debts.seedDebt(
    counterparty: name,
    amount: total,
    payments: payments,
    accountId: account,
    currency: currency,
  );
  fakes.recurring.seed(
    name: name,
    amount: installment,
    accountId: account,
    categoryId: categoryId,
    nextDueDate: next ?? inDays(3),
    debtId: debtId,
    installments: installments,
  );
  return debtId;
}

Future<FakeBackend> open(
  WidgetTester tester,
  FakeBackend fakes, {
  String? route,
  String language = 'es',
}) async {
  tallView(tester);
  await pumpMiPlata(tester, backend: fakes, language: language);
  if (route != null) await goTo(tester, route);
  return fakes;
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);
Finder planSwitch() => find.widgetWithText(SwitchListTile, 'Pagar en cuotas');
Finder registerSwitch() =>
    find.widgetWithText(SwitchListTile, 'Registrar el dinero en una cuenta');

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String controllerText(WidgetTester tester, Finder finder) =>
    tester.widget<TextFormField>(finder).controller!.text;

void main() {
  setUpAll(initDates);

  group('el formulario de la deuda', () {
    Future<void> openForm(WidgetTester tester, FakeBackend fakes) async {
      await open(tester, fakes, route: AppRoutes.debts);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva deuda'));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece pagar en cuotas solo al crear una deuda que debo', (tester) async {
      await openForm(tester, backend());
      expect(planSwitch(), findsOneWidget);

      // Una deuda que me deben no tiene cuotas.
      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<DebtDirection>),
        matching: find.text('Me deben'),
      ));
      await tester.pumpAndSettle();
      expect(planSwitch(), findsNothing);
    });

    testWidgets('al editar una deuda no hay cuotas', (tester) async {
      final fakes = backend();
      fakes.debts.seedDebt(counterparty: 'Juan', amount: 1000);
      await open(tester, fakes, route: AppRoutes.debts);
      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar deuda'));
      await tester.pumpAndSettle();

      expect(planSwitch(), findsNothing);
    });

    testWidgets('activarlo muestra el plan y esconde lo que ya no aplica', (tester) async {
      await openForm(tester, backend());
      expect(find.text('Vencimiento (opcional)'), findsOneWidget);
      expect(registerSwitch(), findsOneWidget);

      await tester.tap(planSwitch());
      await tester.pumpAndSettle();

      expect(find.text('Número de cuotas'), findsOneWidget);
      expect(find.text('Valor de cada cuota'), findsOneWidget);
      expect(find.text('Cada cuánto'), findsOneWidget);
      expect(find.text('Primera cuota'), findsOneWidget);
      expect(find.text('Pagar las cuotas desde'), findsOneWidget);
      expect(find.text('No se descuenta nada hasta que confirmes que pagaste.'), findsOneWidget);
      // Ya no aplican: el vencimiento, registrar el dinero y elegir la moneda.
      expect(find.text('Vencimiento (opcional)'), findsNothing);
      expect(registerSwitch(), findsNothing);
      expect(find.text('COP · Peso colombiano'), findsNothing);

      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Número de cuotas'), findsNothing);
      expect(find.text('Vencimiento (opcional)'), findsOneWidget);
      expect(registerSwitch(), findsOneWidget);
    });

    testWidgets('propone el valor de la cuota: el total entre las cuotas', (tester) async {
      await openForm(tester, backend());
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();

      await tester.enterText(field(1), '2.400.000');
      await tester.enterText(field(3), '12');
      await tester.pump();

      expect(controllerText(tester, field(4)), '200000');
    });

    testWidgets('lo redondea hacia arriba al centavo: la última cuota queda menor', (
      tester,
    ) async {
      await openForm(tester, backend());
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();

      await tester.enterText(field(1), '100');
      await tester.enterText(field(3), '3');
      await tester.pump();

      expect(controllerText(tester, field(4)), '33,34');
    });

    testWidgets('si el usuario escribe la cuota, ya no se la cambia', (tester) async {
      await openForm(tester, backend());
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field(1), '2.400.000');
      await tester.enterText(field(3), '12');
      await tester.pump();

      await tester.enterText(field(4), '250.000'); // con intereses
      await tester.enterText(field(3), '10');
      await tester.pump();

      expect(controllerText(tester, field(4)), '250.000');
    });

    testWidgets('exige cuántas cuotas, el valor y la cuenta', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'TV');
      await tester.enterText(field(1), '2400000');

      for (final count in ['', '0', '361', 'doce']) {
        await tester.enterText(field(3), count);
        await tester.tap(button('Crear deuda'));
        await tester.pump();
        expect(find.text('Escribe cuántas cuotas son (de 1 a 360)'), findsOneWidget,
            reason: 'cuotas "$count"');
      }
      // Con dos cuentas hay que elegir una.
      expect(find.text('Elige una cuenta'), findsOneWidget);
      await tester.enterText(field(3), '12');
      await tester.enterText(field(4), 'mucho');
      await tester.tap(button('Crear deuda'));
      await tester.pump();
      expect(find.text('Monto no válido. Ejemplo: 1.500.000 o 1500,50'), findsOneWidget);
      expect(fakes.debts.calls.where((c) => c.startsWith('createInstallments')), isEmpty);
    });

    testWidgets('crea la deuda y su plan, y el plan aparece en los pagos recurrentes', (
      tester,
    ) async {
      final fakes = backend();
      await openForm(tester, fakes);
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();

      await tester.enterText(field(0), 'TV Samsung');
      await tester.enterText(field(1), '2.400.000');
      await tester.enterText(field(3), '12');
      await tester.pump();
      await pick(tester, find.byType(DropdownButtonFormField<String>).last, 'Bancolombia');
      await pick(tester, find.byType(DropdownButtonFormField<String?>), 'Hogar');
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(
        fakes.debts.calls,
        contains('createInstallments:TV Samsung:2400000:12x200000'),
      );
      final debt = (await fakes.debts.fetchAll()).single;
      expect(debt.counterparty, 'TV Samsung');
      expect(debt.amount, 2400000);
      expect(debt.currency, 'COP');
      // Comprar no mueve dinero: nada entró ni salió de las cuentas.
      expect(fakes.transactions.transactions, isEmpty);

      final plan = fakes.recurring.payments.single;
      expect(plan.debtId, debt.id);
      expect(plan.amount, 200000);
      expect(plan.installments, 12);
      expect(plan.categoryId, 'cat-Hogar');
      expect(plan.recurrence, Recurrence.monthly);

      await goTo(tester, AppRoutes.recurring);
      expect(find.text('Cuota 1 de 12 · Cada mes'), findsOneWidget);
    });

    testWidgets('las cuotas pueden ser de otra frecuencia y la deuda, de otra moneda', (
      tester,
    ) async {
      final fakes = backend();
      await openForm(tester, fakes);
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'Laptop');
      await tester.enterText(field(1), '1.200');
      await tester.enterText(field(3), '6');
      await tester.pump();

      await pick(tester, find.byType(DropdownButtonFormField<Recurrence>), 'Cada 2 semanas');
      await pick(tester, find.byType(DropdownButtonFormField<String>).last, 'Dólares · USD');
      expect(find.text(r'US$ '), findsNWidgets(2)); // el total y la cuota
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect((await fakes.debts.fetchAll()).single.currency, 'USD');
      expect(fakes.recurring.payments.single.recurrence, Recurrence.biweekly);
    });

    testWidgets('con una sola cuenta la elige por ti', (tester) async {
      final fakes = FakeBackend(accounts: [testAccount('Bancolombia', balance: 1000)]);
      await openForm(tester, fakes);
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'Nevera');
      await tester.enterText(field(1), '3000');
      await tester.enterText(field(3), '3');
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments.single.accountId, 'id-Bancolombia');
    });

    testWidgets('sin cuentas no se puede pagar en cuotas', (tester) async {
      await openForm(tester, FakeBackend());

      expect(tester.widget<SwitchListTile>(planSwitch()).onChanged, isNull);
      expect(find.text('Primero crea una cuenta.'), findsWidgets);
    });

    testWidgets('si el servidor falla, lo explica y deja el formulario abierto', (
      tester,
    ) async {
      final fakes = backend();
      await openForm(tester, fakes);
      await tester.tap(planSwitch());
      await tester.pumpAndSettle();
      fakes.debts.error = const PostgrestException(
        message: 'x',
        code: '23514',
        details: 'installment_account_currency',
      );

      await tester.enterText(field(0), 'TV');
      await tester.enterText(field(1), '1000');
      await tester.enterText(field(3), '2');
      await pick(tester, find.byType(DropdownButtonFormField<String>).last, 'Bancolombia');
      await tester.tap(button('Crear deuda'));
      await tester.pumpAndSettle();

      expect(
        find.text('La cuenta de las cuotas tiene que ser de la moneda de la deuda'),
        findsOneWidget,
      );
      expect(button('Crear deuda'), findsOneWidget);
    });
  });

  group('el detalle de la deuda', () {
    testWidgets('una compra a cuotas muestra su plan, cuál toca y cuándo', (tester) async {
      final fakes = backend();
      seedPlan(fakes, payments: [200000, 200000], next: inDays(3));
      await open(tester, fakes, route: AppRoutes.debts);

      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();

      expect(find.text('Plan de cuotas'), findsOneWidget);
      expect(find.text('Cuota 3 de 12 · Cada mes'), findsOneWidget);
      expect(find.text('Pago próximo: vence en 3 días'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ya pagué'), findsOneWidget);
    });

    testWidgets('una deuda normal no tiene plan', (tester) async {
      final fakes = backend();
      fakes.debts.seedDebt(counterparty: 'Juan', amount: 1000);
      await open(tester, fakes, route: AppRoutes.debts);

      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();

      expect(find.text('Plan de cuotas'), findsNothing);
    });

    testWidgets('confirmar la cuota registra un abono y pasa a la siguiente', (
      tester,
    ) async {
      final fakes = backend();
      seedPlan(fakes, categoryId: 'cat-Hogar');
      await open(tester, fakes, route: AppRoutes.debts);
      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();
      expect(find.text(r'Pagado $0'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Ya pagué'));
      await tester.pumpAndSettle();
      // La hoja trae la cuota, cuál es y lo que falta.
      expect(find.text('Cuota 1 de 12 · Falta por pagar: \$2.400.000'), findsOneWidget);
      expect(controllerText(tester, field(0)), '200000');
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      // El abono bajó la deuda, es un gasto y quedó ligado al plan.
      expect(find.text(r'Pagado $200.000'), findsOneWidget);
      final expense = fakes.transactions.transactions.single;
      expect(expense.amount, 200000);
      expect(expense.categoryId, 'cat-Hogar');
      expect(expense.description, 'TV Samsung');
      expect(fakes.debts.calls, contains('registerPayment:debt-1:id-Bancolombia:200000'));
      expect(find.text('Cuota 2 de 12 · Cada mes'), findsOneWidget);
      expect(find.text('Pago registrado'), findsOneWidget);
    });

    testWidgets('la última cuota propone solo lo que falta, y al pagarla el plan termina', (
      tester,
    ) async {
      final fakes = backend();
      seedPlan(
        fakes,
        total: 2400000,
        payments: List.filled(11, 200000.0) + [50000],
        next: inDays(1),
      );
      await open(tester, fakes, route: AppRoutes.debts);
      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();
      expect(find.text('Cuota 12 de 12 · Cada mes'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Ya pagué'));
      await tester.pumpAndSettle();
      expect(controllerText(tester, field(0)), '150000'); // lo que falta
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      // La deuda quedó saldada y el plan, terminado.
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ya pagué'), findsNothing);
      expect(fakes.recurring.payments.single.nextDueDate, isNull);
    });

    testWidgets('si la deuda se salda con un abono suelto, el plan también termina', (
      tester,
    ) async {
      final fakes = backend();
      seedPlan(fakes, total: 400000, installment: 200000, installments: 2);
      await open(tester, fakes, route: AppRoutes.debts);
      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();

      // "Registrar abono" de la deuda, por todo lo que falta.
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar abono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pagar todo'));
      await tester.pump();
      await pick(tester, find.byType(DropdownButtonFormField<String>), 'Bancolombia');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar abono').last);
      await tester.pumpAndSettle();

      expect(find.text('Terminado'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ya pagué'), findsNothing);
    });
  });

  group('en los pagos recurrentes', () {
    testWidgets('la lista dice qué cuota toca', (tester) async {
      final fakes = backend();
      seedPlan(fakes, payments: [200000, 200000, 200000], next: inDays(2));
      await open(tester, fakes, route: AppRoutes.recurring);

      expect(find.text('Cuota 4 de 12 · Cada mes'), findsOneWidget);
      expect(find.text('Pago próximo: vence en 2 días'), findsOneWidget);
    });

    testWidgets('el detalle dice cuánto falta de la deuda', (tester) async {
      final fakes = backend();
      seedPlan(fakes, payments: [200000], next: inDays(2));
      await open(tester, fakes, route: AppRoutes.recurring);

      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();

      expect(find.text('Cuota 2 de 12 · Cada mes'), findsOneWidget);
      expect(find.text(r'Falta por pagar: $2.200.000'), findsOneWidget);
    });

    testWidgets('el dashboard avisa de la cuota próxima, como cualquier pago', (tester) async {
      final fakes = backend();
      seedPlan(fakes, next: inDays(2));
      await open(tester, fakes);

      expect(find.text('Pago próximo: vence en 2 días'), findsOneWidget);
      expect(find.text('Cuota 1 de 12 · Cada mes'), findsOneWidget);
    });

    testWidgets('eliminar el plan conserva la deuda y sus abonos', (tester) async {
      final fakes = backend();
      seedPlan(fakes, payments: [200000], next: inDays(2));
      await open(tester, fakes, route: AppRoutes.recurring);
      await tester.tap(find.text('TV Samsung'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('La deuda y los abonos que ya registraste se conservan.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments, isEmpty);
      expect((await fakes.debts.fetchAll()).single.paid, 200000);
    });

    testWidgets('la cuota de una deuda en dólares solo se paga desde cuentas en dólares', (
      tester,
    ) async {
      final fakes = backend();
      seedPlan(
        fakes,
        name: 'Laptop',
        total: 1200,
        installment: 200,
        installments: 6,
        account: 'id-Dólares',
        currency: 'USD',
        next: inDays(1),
      );
      await open(tester, fakes, route: AppRoutes.recurring);

      await tester.tap(find.widgetWithText(FilledButton, 'Ya pagué'));
      await tester.pumpAndSettle();
      expect(find.text(r'US$ '), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Bancolombia'), findsNothing);
      expect(find.text('Dólares · USD'), findsWidgets);
    });

    testWidgets('omitir una cuota no cambia lo que falta', (tester) async {
      final fakes = backend();
      seedPlan(fakes, next: inDays(1));
      await open(tester, fakes, route: AppRoutes.recurring);

      await tester.tap(find.widgetWithText(FilledButton, 'Ya pagué'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Omitir este pago'));
      await tester.pumpAndSettle();

      expect(fakes.transactions.transactions, isEmpty);
      expect((await fakes.debts.fetchAll()).single.remaining, 2400000);
      expect(find.text('Cuota 1 de 12 · Cada mes'), findsOneWidget); // sigue la primera
    });
  });

  group('en inglés', () {
    testWidgets('el formulario y el plan', (tester) async {
      final fakes = backend();
      seedPlan(fakes, name: 'Fridge', payments: [200000], next: inDays(2));
      await open(tester, fakes, route: AppRoutes.debts, language: 'en');

      await tester.tap(find.text('Fridge'));
      await tester.pumpAndSettle();
      expect(find.text('Installment plan'), findsOneWidget);
      expect(find.text('Installment 2 of 12 · Every month'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New debt'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Pay in installments'));
      await tester.pumpAndSettle();
      expect(find.text('Number of installments'), findsOneWidget);
      expect(find.text('Installment amount'), findsOneWidget);
      expect(find.text('How often'), findsOneWidget);
      expect(find.text('First installment'), findsOneWidget);
      expect(find.text('Pay installments from'), findsOneWidget);
    });
  });
}
