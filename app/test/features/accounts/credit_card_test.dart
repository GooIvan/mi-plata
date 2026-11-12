import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/router/app_routes.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/account_validators.dart';
import 'package:mi_plata/features/accounts/domain/card_calendar.dart';
import 'package:mi_plata/features/accounts/domain/card_usage.dart';
import 'package:mi_plata/features/accounts/presentation/widgets/account_tile.dart';
import 'package:mi_plata/l10n/l10n.dart';

import '../../support/fake_account_repository.dart';
import '../../support/test_app.dart';

late AppLocalizations l10n;

DateTime d(int year, int month, int day) => DateTime(year, month, day);

Future<void> openAccounts(
  WidgetTester tester,
  FakeAccountRepository repository,
) async {
  tallView(tester);
  await pumpMiPlata(tester, accountRepository: repository);
  await goTo(tester, AppRoutes.accounts);
}

Finder formField(int index) => find.byType(TextFormField).at(index);

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
  });

  group('CardCalendar', () {
    // Corte el 15, pago hasta el 30: el extracto del 15 se paga el 30.
    const calendar = CardCalendar(statementDay: 15, paymentDay: 30);

    test(
      'el último corte es el de este mes si ya pasó, o el del mes anterior',
      () {
        expect(calendar.lastStatement(d(2026, 11, 20)), d(2026, 11, 15));
        expect(calendar.lastStatement(d(2026, 11, 10)), d(2026, 10, 15));
        // Hoy es día de corte: el extracto ya cerró.
        expect(calendar.lastStatement(d(2026, 11, 15)), d(2026, 11, 15));
        expect(calendar.lastStatement(d(2026, 1, 3)), d(2025, 12, 15));
      },
    );

    test('el próximo corte es siempre después de hoy', () {
      expect(calendar.nextStatement(d(2026, 11, 10)), d(2026, 11, 15));
      expect(calendar.nextStatement(d(2026, 11, 15)), d(2026, 12, 15));
      expect(calendar.nextStatement(d(2026, 11, 20)), d(2026, 12, 15));
      expect(calendar.nextStatement(d(2026, 12, 20)), d(2027, 1, 15));
    });

    test('un día que el mes no tiene cae en el último día del mes', () {
      const end = CardCalendar(statementDay: 31, paymentDay: 10);
      expect(end.statementIn(2026, 2), d(2026, 2, 28));
      expect(end.statementIn(2028, 2), d(2028, 2, 29));
      expect(end.statementIn(2026, 4), d(2026, 4, 30));
      expect(end.statementIn(2026, 12), d(2026, 12, 31));
      expect(end.lastStatement(d(2026, 5, 10)), d(2026, 4, 30));
    });

    test('el pago es del mismo mes si cae después del corte, y si no, del siguiente', () {
      expect(calendar.paymentFor(d(2026, 11, 15)), d(2026, 11, 30));
      // Corte el 25 y pago el 10: se paga el 10 del mes siguiente.
      const late = CardCalendar(statementDay: 25, paymentDay: 10);
      expect(late.paymentFor(d(2026, 11, 25)), d(2026, 12, 10));
      expect(late.paymentFor(d(2026, 12, 25)), d(2027, 1, 10));
      // El mismo día no sirve: el pago es después del corte.
      const same = CardCalendar(statementDay: 15, paymentDay: 15);
      expect(same.paymentFor(d(2026, 11, 15)), d(2026, 12, 15));
    });

    test('el pago de un mes corto cae en su último día', () {
      const calendar = CardCalendar(statementDay: 5, paymentDay: 31);
      expect(calendar.paymentFor(d(2026, 2, 5)), d(2026, 2, 28));
    });

    test(
      'la próxima fecha de pago cuenta hoy y pasa al extracto siguiente',
      () {
        // El extracto del 15 de nov se paga hasta el 30.
        expect(calendar.nextPayment(d(2026, 11, 20)), d(2026, 11, 30));
        expect(calendar.nextPayment(d(2026, 11, 30)), d(2026, 11, 30));
        // Ya pasó el 30: toca el del extracto que cierra el 15 de diciembre.
        expect(calendar.nextPayment(d(2026, 12, 1)), d(2026, 12, 30));
        // Antes del corte, el extracto anterior ya se pagó (el 30 de octubre).
        expect(calendar.nextPayment(d(2026, 11, 10)), d(2026, 11, 30));
        // Corte el 25 y pago el 10: el 5 de nov todavía se paga el de octubre.
        const late = CardCalendar(statementDay: 25, paymentDay: 10);
        expect(late.nextPayment(d(2026, 11, 5)), d(2026, 11, 10));
        expect(late.nextPayment(d(2026, 11, 11)), d(2026, 12, 10));
      },
    );

    test('un gasto entra en el primer corte desde su fecha', () {
      expect(calendar.statementOf(d(2026, 11, 10)), d(2026, 11, 15));
      // El día del corte todavía entra en ese extracto.
      expect(calendar.statementOf(d(2026, 11, 15)), d(2026, 11, 15));
      expect(calendar.statementOf(d(2026, 11, 16)), d(2026, 12, 15));
      expect(calendar.statementOf(d(2026, 12, 20)), d(2027, 1, 15));
    });

    test('ignora la hora del día', () {
      expect(
        calendar.lastStatement(DateTime(2026, 11, 15, 23, 59)),
        d(2026, 11, 15),
      );
    });
  });

  group('CardUsage', () {
    Account card(double balance, {double? limit}) => testAccount(
      'Visa',
      type: AccountType.card,
      balance: balance,
      creditLimit: limit,
    );

    test('lo usado es la deuda sin el signo y lo disponible, lo que queda', () {
      final usage = CardUsage.of(card(-840000, limit: 3000000));
      expect(usage.usedCents, 84000000);
      expect(usage.limitCents, 300000000);
      expect(usage.availableCents, 216000000);
      expect(usage.ratio, closeTo(0.28, 1e-9));
      expect(usage.level, CardLevel.ok);
    });

    test('sin cupo no hay disponible ni proporción', () {
      final usage = CardUsage.of(card(-100000));
      expect(usage.hasLimit, isFalse);
      expect(usage.availableCents, isNull);
      expect(usage.ratio, isNull);
      expect(usage.level, CardLevel.ok);
    });

    test('un saldo a favor cuenta como cero usado', () {
      final usage = CardUsage.of(card(50000, limit: 1000000));
      expect(usage.usedCents, 0);
      expect(usage.availableCents, 100000000);
    });

    test('avisa desde el 80 % y distingue cuando se pasó del cupo', () {
      expect(CardUsage.of(card(-790000, limit: 1000000)).level, CardLevel.ok);
      expect(CardUsage.of(card(-800000, limit: 1000000)).level, CardLevel.high);
      // Justo en el cupo todavía no se pasó.
      expect(
        CardUsage.of(card(-1000000, limit: 1000000)).level,
        CardLevel.high,
      );
      final over = CardUsage.of(card(-1200000, limit: 1000000));
      expect(over.level, CardLevel.over);
      expect(over.availableCents, -20000000);
    });

    test('suma en centavos enteros, sin ruido de coma flotante', () {
      final usage = CardUsage.of(card(-0.1 - 0.2, limit: 1));
      expect(usage.usedCents, 30);
    });
  });

  group('Account.fromJson', () {
    test('lee el cupo y los días de una tarjeta', () {
      final account = Account.fromJson({
        'id': 'a',
        'name': 'Visa',
        'type': 'card',
        'currency': 'COP',
        'is_archived': false,
        'initial_balance': 0,
        'current_balance': -840000,
        'credit_limit': 3000000.00,
        'statement_day': 15,
        'payment_day': 30,
      });
      expect(account.isCard, isTrue);
      expect(account.creditLimit, 3000000);
      expect(account.statementDay, 15);
      expect(account.paymentDay, 30);
      expect(account.cardCalendar?.statementDay, 15);
    });

    test('una cuenta sin esos datos no tiene calendario', () {
      final account = Account.fromJson({
        'id': 'a',
        'name': 'Banco',
        'type': 'bank',
        'currency': 'COP',
        'is_archived': false,
        'initial_balance': 0,
        'current_balance': 0,
        'credit_limit': null,
        'statement_day': null,
        'payment_day': null,
      });
      expect(account.creditLimit, isNull);
      expect(account.cardCalendar, isNull);
    });
  });

  group('validadores de la tarjeta', () {
    test('el cupo puede ir vacío, y si se escribe debe ser mayor que cero', () {
      expect(AccountValidators.creditLimit(l10n, ''), isNull);
      expect(AccountValidators.creditLimit(l10n, null), isNull);
      expect(AccountValidators.creditLimit(l10n, '3.000.000'), isNull);
      expect(AccountValidators.creditLimit(l10n, '0'), isNotNull);
      expect(AccountValidators.creditLimit(l10n, '-5'), isNotNull);
      expect(AccountValidators.creditLimit(l10n, 'mucho'), isNotNull);
    });

    test('un día va del 1 al 31', () {
      expect(AccountValidators.cardDay(l10n, ''), isNull);
      expect(AccountValidators.cardDay(l10n, '1'), isNull);
      expect(AccountValidators.cardDay(l10n, '31'), isNull);
      expect(AccountValidators.cardDay(l10n, '0'), isNotNull);
      expect(AccountValidators.cardDay(l10n, '32'), isNotNull);
      expect(AccountValidators.cardDay(l10n, 'x'), isNotNull);
    });

    test('los dos días van juntos o ninguno', () {
      expect(AccountValidators.cardDaysTogether(l10n, '', ''), isNull);
      expect(AccountValidators.cardDaysTogether(l10n, '15', '30'), isNull);
      expect(AccountValidators.cardDaysTogether(l10n, '15', ''), isNotNull);
      expect(AccountValidators.cardDaysTogether(l10n, '', '30'), isNotNull);
    });
  });

  group('lista de cuentas', () {
    testWidgets(
      'una tarjeta con cupo muestra lo usado, lo disponible y las fechas',
      (tester) async {
        await openAccounts(
          tester,
          FakeAccountRepository([
            testAccount(
              'Visa',
              type: AccountType.card,
              balance: -840000,
              creditLimit: 3000000,
              statementDay: 15,
              paymentDay: 30,
            ),
          ]),
        );

        expect(textLike(r'Usado $840.000 de $3.000.000'), findsOneWidget);
        expect(textLike(r'Disponible $2.160.000'), findsOneWidget);
        expect(find.textContaining('Corte'), findsOneWidget);
        expect(find.textContaining('Pagar antes del'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'pasarse del cupo se dice con texto e ícono, no solo con color',
      (tester) async {
        await openAccounts(
          tester,
          FakeAccountRepository([
            testAccount(
              'Visa',
              type: AccountType.card,
              balance: -1200000,
              creditLimit: 1000000,
            ),
          ]),
        );

        expect(textLike(r'Te pasaste del cupo por $200.000'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        // Sin fechas, no hay línea de corte.
        expect(find.textContaining('Corte'), findsNothing);
      },
    );

    testWidgets('una tarjeta sin cupo ni fechas se ve como cualquier cuenta', (
      tester,
    ) async {
      await openAccounts(
        tester,
        FakeAccountRepository([
          testAccount('Visa', type: AccountType.card, balance: -50000),
        ]),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Usado'), findsNothing);
    });

    testWidgets('las otras cuentas no muestran nada de tarjeta', (
      tester,
    ) async {
      await openAccounts(
        tester,
        FakeAccountRepository([testAccount('Banco', balance: 100000)]),
      );

      expect(find.byType(CardSummary), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('formulario', () {
    Future<void> openForm(
      WidgetTester tester,
      FakeAccountRepository repo,
    ) async {
      await openAccounts(tester, repo);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Nueva cuenta'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el cupo y los días solo aparecen al elegir Tarjeta', (
      tester,
    ) async {
      await openForm(tester, FakeAccountRepository());

      expect(find.text('Cupo (opcional)'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tarjeta'));
      await tester.pumpAndSettle();

      expect(find.text('Cupo (opcional)'), findsOneWidget);
      expect(find.text('Día de corte (opcional)'), findsOneWidget);
      expect(find.text('Día límite de pago (opcional)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Banco'));
      await tester.pumpAndSettle();
      expect(find.text('Cupo (opcional)'), findsNothing);
    });

    testWidgets('crea una tarjeta con su cupo y sus días', (tester) async {
      final repository = FakeAccountRepository();
      await openForm(tester, repository);

      await tester.enterText(formField(0), 'Visa Gold');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tarjeta'));
      await tester.pumpAndSettle();
      // 0 nombre, 1 saldo inicial, 2 cupo, 3 corte, 4 pago.
      await tester.enterText(formField(2), '3.000.000');
      await tester.enterText(formField(3), '15');
      await tester.enterText(formField(4), '30');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains(
          'create:Visa Gold:card:0:limit=3000000:statement=15:payment=30',
        ),
      );
      expect(textLike(r'Disponible $3.000.000'), findsOneWidget);
    });

    testWidgets('el cupo y los días se pueden dejar vacíos', (tester) async {
      final repository = FakeAccountRepository();
      await openForm(tester, repository);

      await tester.enterText(formField(0), 'Visa');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Visa:card:0'));
    });

    testWidgets('un día sin el otro no se guarda', (tester) async {
      final repository = FakeAccountRepository();
      await openForm(tester, repository);

      await tester.enterText(formField(0), 'Visa');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tarjeta'));
      await tester.pumpAndSettle();
      await tester.enterText(formField(3), '15');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pump();

      expect(
        find.text('Indica los dos días, o deja los dos vacíos'),
        findsOneWidget,
      );
      expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('un día fuera de rango y un cupo en cero se rechazan', (
      tester,
    ) async {
      final repository = FakeAccountRepository();
      await openForm(tester, repository);

      await tester.enterText(formField(0), 'Visa');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tarjeta'));
      await tester.pumpAndSettle();
      await tester.enterText(formField(2), '0');
      await tester.enterText(formField(3), '32');
      await tester.enterText(formField(4), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pump();

      expect(
        find.text('El cupo tiene que ser un monto mayor que cero'),
        findsOneWidget,
      );
      expect(find.text('Escribe un día del 1 al 31'), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('editar una tarjeta precarga el cupo y los días', (
      tester,
    ) async {
      final repository = FakeAccountRepository([
        testAccount(
          'Visa',
          type: AccountType.card,
          creditLimit: 3000000,
          statementDay: 15,
          paymentDay: 30,
        ),
      ]);
      await openAccounts(tester, repository);

      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '3000000'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);

      await tester.enterText(formField(2), '5.000.000');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains(
          'update:id-Visa:Visa:card:0:limit=5000000:statement=15:payment=30',
        ),
      );
    });

    testWidgets('pasar una tarjeta a otro tipo borra su cupo y sus días', (
      tester,
    ) async {
      final repository = FakeAccountRepository([
        testAccount(
          'Visa',
          type: AccountType.card,
          creditLimit: 3000000,
          statementDay: 15,
          paymentDay: 30,
        ),
      ]);
      await openAccounts(tester, repository);

      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Banco'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('update:id-Visa:Visa:bank:0'));
    });
  });
}
