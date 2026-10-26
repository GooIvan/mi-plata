import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/budgets/domain/budget_rule.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final _now = DateTime.now();
DateTime inDays(int days) => DateTime(_now.year, _now.month, _now.day + days);

FakeBackend backend() => FakeBackend(
  accounts: [
    testAccount('Bancolombia', balance: 1000000),
    testAccount('Nequi', balance: 4000),
  ],
  categories: [
    testCategory('Entretenimiento', CategoryType.expense),
    testCategory('Vivienda', CategoryType.expense),
    testCategory('Salario', CategoryType.income),
  ],
);

Future<FakeBackend> open(
  WidgetTester tester,
  FakeBackend fakes, {
  String? route = AppRoutes.recurring,
  String language = 'es',
}) async {
  tallView(tester);
  await pumpMiPlata(tester, backend: fakes, language: language);
  if (route != null) await goTo(tester, route);
  return fakes;
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder button(String label) => find.widgetWithText(FilledButton, label);
Finder tonal(String label) => find.widgetWithText(FilledButton, label);

/// El botón "Ya pagué" de la ficha de un pago.
Finder payButton(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first,
  matching: find.widgetWithText(FilledButton, 'Ya pagué'),
);

/// Quita los avisos que haya en pantalla: se encolan, y el siguiente no sale
/// hasta que el anterior se cierre.
void clearSnackBars(WidgetTester tester) => ScaffoldMessenger.of(
  tester.element(find.byType(Scaffold).first),
).clearSnackBars();

Future<void> pick(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initDates);

  group('la lista', () {
    testWidgets('sin pagos recurrentes invita a registrar el primero', (tester) async {
      await open(tester, backend());

      expect(find.widgetWithText(AppBar, 'Pagos recurrentes'), findsOneWidget);
      expect(find.textContaining('Aún no registras pagos recurrentes'), findsOneWidget);
      expect(find.text('Registrar pago recurrente'), findsOneWidget);

      await tester.tap(find.text('Registrar pago recurrente'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Nuevo pago recurrente'), findsOneWidget);
    });

    testWidgets('lo urgente primero, cada pago con su estado', (tester) async {
      final fakes = backend();
      fakes.recurring
        ..seed(name: 'Seguro', amount: 90000, nextDueDate: inDays(20), recurrence: Recurrence.yearly)
        ..seed(name: 'Netflix', amount: 30000, nextDueDate: inDays(3))
        ..seed(name: 'Arriendo', amount: 1500000, nextDueDate: inDays(-2))
        ..seed(name: 'Gimnasio', amount: 80000, nextDueDate: inDays(1), paused: true)
        ..seed(name: 'Curso', amount: 50000, nextDueDate: inDays(-40), endDate: inDays(-40));
      // Un pago al que ya no le quedan fechas.
      await fakes.recurring.skip('rec-5');
      await open(tester, fakes);

      expect(find.text('Activos'), findsOneWidget);
      expect(find.text('En pausa o terminados'), findsOneWidget);
      expect(find.text('Vencido hace 2 días'), findsOneWidget);
      expect(find.text('Pago próximo: vence en 3 días'), findsOneWidget);
      expect(find.textContaining('Próximo pago el'), findsOneWidget); // el seguro
      expect(find.text('En pausa'), findsOneWidget);
      expect(find.text('Terminado'), findsOneWidget);

      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Arriendo'), lessThan(top('Netflix')));
      expect(top('Netflix'), lessThan(top('Seguro')));
      expect(top('Seguro'), lessThan(top('Gimnasio')));
      expect(top('Gimnasio'), lessThan(top('Curso')));

      // Cada uno con su monto y su frecuencia.
      expect(textLike(r'$1.500.000'), findsOneWidget);
      expect(find.text('Cada mes'), findsNWidgets(4));
      expect(find.text('Cada año'), findsOneWidget);
    });

    testWidgets('el botón "Ya pagué" solo sale en lo que pide atención', (tester) async {
      final fakes = backend();
      fakes.recurring
        ..seed(name: 'Seguro', nextDueDate: inDays(20))
        ..seed(name: 'Netflix', nextDueDate: inDays(3))
        ..seed(name: 'Arriendo', nextDueDate: inDays(-2))
        ..seed(name: 'Gimnasio', nextDueDate: inDays(1), paused: true);
      await open(tester, fakes);

      expect(payButton('Arriendo'), findsOneWidget);
      expect(payButton('Netflix'), findsOneWidget);
      expect(payButton('Seguro'), findsNothing);
      expect(payButton('Gimnasio'), findsNothing);
    });

    testWidgets('tocar un pago abre su detalle', (tester) async {
      final fakes = backend()..recurring.seed(name: 'Netflix', nextDueDate: inDays(3));
      await open(tester, fakes);

      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Netflix'), findsOneWidget);
      expect(find.text('Pagos registrados'), findsOneWidget);
    });

    testWidgets('si falla la carga, ofrece reintentar', (tester) async {
      final fakes = backend();
      fakes.recurring.error = Exception('boom');
      await open(tester, fakes);

      expect(find.text('Reintentar'), findsOneWidget);
      fakes.recurring.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('confirmar un pago', () {
    Future<FakeBackend> openWithNetflix(WidgetTester tester, {FakeBackend? base}) async {
      final fakes = base ?? backend();
      fakes.recurring.seed(
        name: 'Netflix',
        amount: 30000,
        categoryId: 'cat-Entretenimiento',
        nextDueDate: inDays(2),
      );
      await open(tester, fakes);
      await tester.tap(payButton('Netflix'));
      await tester.pumpAndSettle();
      return fakes;
    }

    testWidgets('la hoja trae todo listo: monto, cuenta, fecha y cómo va el pago', (
      tester,
    ) async {
      await openWithNetflix(tester);

      expect(find.text('Pago de Netflix'), findsOneWidget);
      expect(find.text('Pago próximo: vence en 2 días'), findsWidgets);
      expect(tester.widget<TextFormField>(field(0)).controller?.text, '30000');
      expect(find.text('Bancolombia'), findsWidgets); // la cuenta de siempre
      expect(find.text('Confirmar pago'), findsOneWidget);
      expect(find.text('Omitir este pago'), findsOneWidget);
    });

    testWidgets('hasta que se confirma, no se descuenta nada', (tester) async {
      final fakes = await openWithNetflix(tester);

      expect(fakes.transactions.created, isEmpty);
      expect(fakes.transactions.transactions, isEmpty);
      final balance = (await fakes.accounts.fetchAll()).firstWhere((a) => a.name == 'Bancolombia');
      expect(balance.currentBalance, 1000000);
      expect(fakes.recurring.calls.where((c) => c.startsWith('confirm')), isEmpty);
    });

    testWidgets('confirmar crea el gasto y pasa al siguiente pago', (tester) async {
      final fakes = await openWithNetflix(tester);
      final due = fakes.recurring.payments.single.nextDueDate!;

      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.calls, contains('confirm:rec-1:id-Bancolombia:30000'));
      final expense = fakes.transactions.transactions.single;
      expect(expense.type, TransactionType.expense);
      expect(expense.amount, 30000);
      expect(expense.categoryId, 'cat-Entretenimiento');
      expect(expense.description, 'Netflix');
      expect(DateUtils.isSameDay(expense.date, _now), isTrue);

      // La regla pasó al mes siguiente.
      final next = fakes.recurring.payments.single.nextDueDate!;
      expect(next, Recurrence.monthly.advance(due, anchorDay: due.day));

      // El saldo bajó y se avisó.
      final balance = (await fakes.accounts.fetchAll()).firstWhere((a) => a.name == 'Bancolombia');
      expect(balance.currentBalance, 970000);
      expect(find.text('Pago registrado'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('se puede cambiar el monto, la cuenta, la fecha y la descripción', (
      tester,
    ) async {
      final fakes = await openWithNetflix(tester);

      await tester.enterText(field(0), '35.500');
      await pick(tester, find.byType(DropdownButtonFormField<String>), 'Bancolombia');
      await tester.enterText(field(1), 'Con el aumento');
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.pump();
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      final expense = fakes.transactions.transactions.single;
      expect(expense.amount, 35500);
      expect(expense.description, 'Con el aumento');
      expect(expense.date.day, 1);
      expect(fakes.recurring.payments.single.amount, 30000); // la regla no cambia
    });

    testWidgets('el monto es obligatorio y tiene que ser válido', (tester) async {
      final fakes = await openWithNetflix(tester);

      for (final (input, message) in [
        ('', 'Ingresa el monto'),
        ('0', 'El monto debe ser mayor que cero'),
        ('abc', 'Monto no válido. Ejemplo: 1.500.000 o 1500,50'),
      ]) {
        await tester.enterText(field(0), input);
        await tester.tap(button('Confirmar pago'));
        await tester.pump();
        expect(find.text(message), findsOneWidget, reason: 'entrada "$input"');
      }
      expect(fakes.recurring.calls.where((c) => c.startsWith('confirm')), isEmpty);
    });

    testWidgets('pagar de una cuenta que no alcanza avisa antes', (tester) async {
      final fakes = await openWithNetflix(tester);

      await pick(tester, find.byType(DropdownButtonFormField<String>), 'Nequi');
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(find.text('¿Registrar de todos modos?'), findsOneWidget);
      expect(find.textContaining(r'Nequi quedará en -$26.000.'), findsOneWidget);
      expect(fakes.transactions.transactions, isEmpty);

      // "Corregir" vuelve a la hoja sin pagar.
      await tester.tap(find.widgetWithText(TextButton, 'Corregir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fakes.recurring.calls.where((c) => c.startsWith('confirm')), isEmpty);

      // "Registrar igual" sí lo registra.
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar igual'));
      await tester.pumpAndSettle();
      expect(fakes.recurring.calls, contains('confirm:rec-1:id-Nequi:30000'));
    });

    testWidgets('omitir pasa al siguiente sin crear ningún movimiento', (tester) async {
      final fakes = await openWithNetflix(tester);
      final due = fakes.recurring.payments.single.nextDueDate!;

      await tester.tap(find.text('Omitir este pago'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.calls, contains('skip:rec-1'));
      expect(fakes.transactions.transactions, isEmpty);
      expect(
        fakes.recurring.payments.single.nextDueDate,
        Recurrence.monthly.advance(due, anchorDay: due.day),
      );
      expect(find.text('Pago omitido'), findsOneWidget);
    });

    testWidgets('si el servidor falla, avisa y deja la hoja abierta', (tester) async {
      final fakes = await openWithNetflix(tester);
      fakes.recurring.error = const PostgrestException(
        message: 'Este pago recurrente ya terminó',
        code: '23514',
        details: 'recurring_finished',
      );

      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(find.text('Este pago recurrente ya terminó'), findsOneWidget);
      expect(find.text('Confirmar pago'), findsOneWidget);
      expect(fakes.transactions.transactions, isEmpty);
    });

    testWidgets('el gasto cuenta contra el presupuesto, y se avisa si lo pasa', (
      tester,
    ) async {
      final fakes = FakeBackend(
        accounts: [testAccount('Bancolombia', balance: 1000000)],
        categories: [testCategory('Entretenimiento', CategoryType.expense)],
        transactions: [
          testTransaction(
            't1',
            type: TransactionType.expense,
            accountId: 'id-Bancolombia',
            categoryId: 'cat-Entretenimiento',
            amount: 80000,
            date: inDays(0),
          ),
        ],
        budgets: [
          BudgetRule(
            id: 'r1',
            categoryId: 'cat-Entretenimiento',
            month: DateTime(_now.year, _now.month),
            cents: 10000000,
          ),
        ],
      );
      await openWithNetflix(tester, base: fakes);

      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(r'Superaste el presupuesto de Entretenimiento: $110.000 de $100.000.'),
        findsOneWidget,
      );
    });

    testWidgets('un pago vencido varios meses se confirma de a uno', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(
        name: 'Arriendo',
        amount: 500000,
        nextDueDate: DateTime(_now.year, _now.month - 2, 5),
      );
      await open(tester, fakes);
      expect(find.textContaining('Vencido hace'), findsOneWidget);

      await tester.tap(payButton('Arriendo'));
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      // Quedó el mes siguiente, que también está vencido: se confirma o se omite.
      expect(fakes.transactions.transactions, hasLength(1));
      expect(find.textContaining('Vencido hace'), findsOneWidget);
      expect(payButton('Arriendo'), findsOneWidget);
    });

    testWidgets('al llegar a la fecha final el pago termina', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(
        name: 'Curso',
        amount: 50000,
        nextDueDate: inDays(2),
        endDate: inDays(10),
      );
      await open(tester, fakes);

      await tester.tap(payButton('Curso'));
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(find.text('Terminado'), findsOneWidget);
      expect(fakes.recurring.payments.single.isFinished, isTrue);
      expect(payButton('Curso'), findsNothing);
    });
  });

  group('el detalle', () {
    Future<FakeBackend> openDetail(WidgetTester tester, {FakeBackend? base}) async {
      final fakes = base ?? backend();
      fakes.recurring.seed(
        name: 'Netflix',
        amount: 30000,
        categoryId: 'cat-Entretenimiento',
        nextDueDate: inDays(12),
        endDate: inDays(400),
      );
      await open(tester, fakes);
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      return fakes;
    }

    testWidgets('muestra el pago, cuándo toca y que aún no hay pagos', (tester) async {
      await openDetail(tester);

      expect(find.text('Cada mes'), findsOneWidget);
      expect(textLike(r'$30.000'), findsOneWidget);
      expect(find.textContaining('Próximo pago el'), findsOneWidget);
      expect(find.text('Se paga desde: Bancolombia'), findsOneWidget);
      expect(find.text('Categoría: Entretenimiento'), findsOneWidget);
      expect(find.textContaining('Termina el'), findsOneWidget);
      expect(find.text('Aún no has registrado ningún pago.'), findsOneWidget);
    });

    testWidgets('"Ya pagué" funciona también con tiempo de sobra, y queda en el historial', (
      tester,
    ) async {
      final fakes = await openDetail(tester);

      await tester.tap(button('Ya pagué'));
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(fakes.transactions.transactions, hasLength(1));
      expect(find.text('Aún no has registrado ningún pago.'), findsNothing);
      expect(textLike(r'$30.000'), findsNWidgets(2)); // el monto y el pago registrado
      expect(find.textContaining('Bancolombia'), findsWidgets);
    });

    testWidgets('pausar y reanudar', (tester) async {
      final fakes = await openDetail(tester);

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments.single.isPaused, isTrue);
      expect(find.text('Pago pausado'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);

      clearSnackBars(tester);
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reanudar'));
      await tester.pumpAndSettle();
      expect(fakes.recurring.payments.single.isPaused, isFalse);
      expect(find.text('Pago reanudado'), findsOneWidget);
    });

    testWidgets('eliminar pide confirmar y deja los gastos que ya se registraron', (
      tester,
    ) async {
      final fakes = await openDetail(tester);
      await tester.tap(button('Ya pagué'));
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      clearSnackBars(tester);
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este pago recurrente?'), findsOneWidget);
      expect(find.text('Los pagos que ya registraste se conservan.'), findsOneWidget);

      // Cancelar no borra nada.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(fakes.recurring.payments, hasLength(1));

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments, isEmpty);
      expect(fakes.transactions.transactions, hasLength(1)); // el gasto se queda
      expect(find.text('Pago recurrente eliminado'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Pagos recurrentes'), findsOneWidget);
    });

    testWidgets('un pago terminado no se puede confirmar', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(name: 'Curso', nextDueDate: inDays(1), endDate: inDays(1));
      await fakes.recurring.skip('rec-1');
      await open(tester, fakes);
      await tester.tap(find.text('Curso'));
      await tester.pumpAndSettle();

      expect(find.text('Terminado'), findsOneWidget);
      expect(tester.widget<FilledButton>(button('Ya pagué')).onPressed, isNull);
      // Y solo se puede eliminar, no pausar.
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Pausar'), findsNothing);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('editarlo cambia lo que se muestra', (tester) async {
      final fakes = await openDetail(tester);

      await tester.tap(find.byTooltip('Editar pago recurrente'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field(0)).controller?.text, 'Netflix');
      expect(tester.widget<TextFormField>(field(1)).controller?.text, '30000');
      await tester.enterText(field(1), '34.900');
      await tester.tap(button('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.calls.any((c) => c.startsWith('update:rec-1:Netflix:34900')), isTrue);
      expect(textLike(r'$34.900'), findsOneWidget);
    });
  });

  group('el formulario', () {
    Future<void> openForm(WidgetTester tester, FakeBackend fakes) async {
      await open(tester, fakes);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWidgets('registra un pago recurrente y no descuenta nada', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);

      expect(find.text('No se descuenta nada hasta que confirmes que pagaste.'), findsOneWidget);
      await tester.enterText(field(0), 'Arriendo');
      await tester.enterText(field(1), '1.500.000');
      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Bancolombia');
      await pick(tester, find.byType(DropdownButtonFormField<String?>), 'Vivienda');
      await tester.tap(button('Crear pago recurrente'));
      await tester.pumpAndSettle();

      final payment = fakes.recurring.payments.single;
      expect(payment.name, 'Arriendo');
      expect(payment.amount, 1500000);
      expect(payment.accountId, 'id-Bancolombia');
      expect(payment.categoryId, 'cat-Vivienda');
      expect(payment.recurrence, Recurrence.monthly);
      expect(DateUtils.isSameDay(payment.nextDueDate, _now), isTrue);
      expect(payment.anchorDay, _now.day);
      expect(fakes.transactions.transactions, isEmpty);
      expect(find.text('Arriendo'), findsOneWidget); // volvió a la lista
    });

    testWidgets('solo ofrece categorías de gasto', (tester) async {
      await openForm(tester, backend());

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Vivienda'), findsWidgets);
      expect(find.text('Salario'), findsNothing);
    });

    testWidgets('ofrece las frecuencias de siempre', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);

      await tester.tap(find.byType(DropdownButtonFormField<Recurrence>));
      await tester.pumpAndSettle();
      for (final label in [
        'Cada semana',
        'Cada 2 semanas',
        'Cada mes',
        'Cada 2 meses',
        'Cada 3 meses',
        'Cada 6 meses',
        'Cada año',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }

      await tester.tap(find.text('Cada 3 meses').last);
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'Seguro');
      await tester.enterText(field(1), '300.000');
      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Bancolombia');
      await tester.tap(button('Crear pago recurrente'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments.single.recurrence, Recurrence.quarterly);
    });

    testWidgets('exige nombre, monto y cuenta', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);

      await tester.tap(button('Crear pago recurrente'));
      await tester.pump();

      expect(find.text('Ponle un nombre al pago'), findsOneWidget);
      expect(find.text('Ingresa el monto'), findsOneWidget);
      expect(find.text('Elige una cuenta'), findsOneWidget);
      expect(fakes.recurring.payments, isEmpty);
    });

    testWidgets('con una sola cuenta la elige por ti', (tester) async {
      final fakes = FakeBackend(accounts: [testAccount('Bancolombia', balance: 1000)]);
      await openForm(tester, fakes);

      await tester.enterText(field(0), 'Spotify');
      await tester.enterText(field(1), '17.900');
      await tester.tap(button('Crear pago recurrente'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.payments.single.accountId, 'id-Bancolombia');
    });

    testWidgets('una fecha final anterior al próximo pago no se acepta', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);
      await tester.enterText(field(0), 'Curso');
      await tester.enterText(field(1), '50000');
      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Bancolombia');

      // Abre el selector de la fecha final y elige el día 1 (o el primero del
      // mes siguiente si hoy es 1).
      await tester.tap(find.text('Sin fecha final'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.pump();
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      if (_now.day > 1) {
        expect(find.text('La fecha final no puede ser anterior al próximo pago'), findsOneWidget);
        await tester.tap(button('Crear pago recurrente'));
        await tester.pump();
        expect(fakes.recurring.payments, isEmpty);
      }
    });

    testWidgets('la fecha final se puede quitar', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(name: 'Curso', nextDueDate: inDays(3), endDate: inDays(90));
      await open(tester, fakes);
      await tester.tap(find.text('Curso'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar pago recurrente'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quitar la fecha final'));
      await tester.pumpAndSettle();
      expect(find.text('Sin fecha final'), findsOneWidget);
      await tester.tap(button('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(fakes.recurring.calls.any((c) => c.startsWith('update:rec-1')), isTrue);
    });

    testWidgets('el monto lleva la moneda de la cuenta elegida', (tester) async {
      final fakes = FakeBackend(accounts: [
        testAccount('Bancolombia', balance: 1000),
        testAccount('Dólares', balance: 5, currency: 'USD'),
      ]);
      await openForm(tester, fakes);

      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Dólares · USD');

      expect(find.text(r'US$ '), findsOneWidget);
    });

    testWidgets('sin cuentas pide crear una primero', (tester) async {
      await openForm(tester, FakeBackend());

      expect(find.text('Primero crea una cuenta para registrar movimientos.'), findsOneWidget);
    });

    testWidgets('si el servidor falla, avisa y deja el formulario abierto', (tester) async {
      final fakes = backend();
      await openForm(tester, fakes);
      fakes.recurring.error = const PostgrestException(
        message: 'x',
        code: '23514',
        details: 'recurring_category_mismatch',
      );
      await tester.enterText(field(0), 'Arriendo');
      await tester.enterText(field(1), '1000');
      await pick(tester, find.byType(DropdownButtonFormField<String>).first, 'Bancolombia');
      await tester.tap(button('Crear pago recurrente'));
      await tester.pumpAndSettle();

      expect(find.text('Solo las categorías de gasto sirven en un pago recurrente'), findsOneWidget);
      expect(button('Crear pago recurrente'), findsOneWidget);
    });
  });

  group('en el panel', () {
    testWidgets('sin pagos recurrentes invita a registrarlos', (tester) async {
      await open(tester, backend(), route: null);

      expect(find.text('Pagos recurrentes'), findsOneWidget);
      expect(find.text('Registra tus suscripciones y el arriendo'), findsOneWidget);

      await tester.tap(find.text('Registra tus suscripciones y el arriendo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Pagos recurrentes'), findsOneWidget);
    });

    testWidgets('lo que vence pronto sale con su botón, lo urgente primero', (tester) async {
      final fakes = backend();
      fakes.recurring
        ..seed(name: 'Netflix', amount: 30000, nextDueDate: inDays(3))
        ..seed(name: 'Arriendo', amount: 1500000, nextDueDate: inDays(-1))
        ..seed(name: 'Seguro', amount: 90000, nextDueDate: inDays(30));
      await open(tester, fakes, route: null);

      expect(find.text('Vencido hace 1 día'), findsOneWidget);
      expect(find.text('Pago próximo: vence en 3 días'), findsOneWidget);
      expect(find.text('Seguro'), findsNothing); // todavía falta
      expect(payButton('Arriendo'), findsOneWidget);
      expect(payButton('Netflix'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Arriendo')).dy,
        lessThan(tester.getTopLeft(find.text('Netflix')).dy),
      );
    });

    testWidgets('"Ya pagué" desde el panel registra el gasto y baja el total', (
      tester,
    ) async {
      final fakes = backend();
      fakes.recurring.seed(name: 'Netflix', amount: 30000, nextDueDate: inDays(1));
      await open(tester, fakes, route: null);
      expect(textLike(r'$1.004.000'), findsOneWidget);

      await tester.tap(payButton('Netflix'));
      await tester.pumpAndSettle();
      await tester.tap(button('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(textLike(r'$974.000'), findsOneWidget);
      // Ya no pide atención: el siguiente pago es dentro de un mes.
      expect(payButton('Netflix'), findsNothing);
      expect(find.textContaining('No tienes pagos próximos.'), findsOneWidget);
    });

    testWidgets('muestra como máximo tres', (tester) async {
      final fakes = backend();
      for (var i = 1; i <= 5; i++) {
        fakes.recurring.seed(name: 'Pago $i', nextDueDate: inDays(i));
      }
      await open(tester, fakes, route: null);

      expect(find.text('Pago 1'), findsOneWidget);
      expect(find.text('Pago 3'), findsOneWidget);
      expect(find.text('Pago 4'), findsNothing);
    });

    testWidgets('sin nada próximo, dice cuál es el siguiente', (tester) async {
      final fakes = backend();
      fakes.recurring
        ..seed(name: 'Seguro', nextDueDate: inDays(40))
        ..seed(name: 'Curso', nextDueDate: inDays(25));
      await open(tester, fakes, route: null);

      expect(find.textContaining('No tienes pagos próximos.'), findsOneWidget);
      expect(find.textContaining('Siguiente: Curso'), findsOneWidget);
    });

    testWidgets('un pago en pausa no avisa', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(name: 'Gimnasio', nextDueDate: inDays(-3), paused: true);
      await open(tester, fakes, route: null);

      expect(find.text('Gimnasio'), findsNothing);
      expect(find.textContaining('No tienes pagos próximos.'), findsOneWidget);
    });

    testWidgets('"Ver todos" abre la lista', (tester) async {
      final fakes = backend();
      fakes.recurring.seed(name: 'Netflix', nextDueDate: inDays(3));
      await open(tester, fakes, route: null);

      // El primero de los "Ver todos" es el de los pagos recurrentes.
      await tester.tap(find.widgetWithText(TextButton, 'Ver todos').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Pagos recurrentes'), findsOneWidget);
    });
  });

  group('en inglés', () {
    testWidgets('lista, estado y hoja de confirmación', (tester) async {
      final fakes = backend();
      fakes.recurring
        ..seed(name: 'Rent', amount: 500000, nextDueDate: inDays(-2))
        ..seed(name: 'Netflix', amount: 30000, nextDueDate: inDays(3), categoryId: 'cat-Entretenimiento');
      await open(tester, fakes, language: 'en');

      expect(find.widgetWithText(AppBar, 'Recurring payments'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Overdue by 2 days'), findsOneWidget);
      expect(find.text('Upcoming payment: due in 3 days'), findsOneWidget);
      expect(find.text('Every month'), findsNWidgets(2));

      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Netflix'), matching: find.byType(InkWell)).first,
        matching: find.widgetWithText(FilledButton, 'I paid'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Payment for Netflix'), findsOneWidget);
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.text('Skip this payment'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Payment recorded'), findsOneWidget);
    });
  });
}
