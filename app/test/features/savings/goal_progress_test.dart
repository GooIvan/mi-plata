import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/savings/domain/goal_draft.dart';
import 'package:mi_plata/features/savings/domain/goal_movement.dart';
import 'package:mi_plata/features/savings/domain/goal_progress.dart';
import 'package:mi_plata/features/savings/domain/goal_validators.dart';
import 'package:mi_plata/features/savings/domain/savings_goal.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

final today = DateTime(2026, 10, 26);

GoalProgress progress({
  int target = 1000000,
  int balance = 0,
  DateTime? date,
  String name = 'Viaje',
}) => GoalProgress(
  goal: SavingsGoal(
    id: 'goal-$name',
    name: name,
    targetCents: target,
    accountId: 'acc',
    isArchived: false,
    targetDate: date,
  ),
  accountName: 'Ahorros',
  currency: 'COP',
  balanceCents: balance,
);

void main() {
  setUpAll(initDates);

  group('el avance', () {
    test('lo ahorrado es el saldo de la cuenta', () {
      final p = progress(target: 1000000, balance: 250000);

      expect(p.savedCents, 250000);
      expect(p.remainingCents, 750000);
      expect(p.fraction, 0.25);
      expect(p.percent, 25);
      expect(p.isReached, isFalse);
    });

    test('el porcentaje no dice 100 antes de llegar', () {
      final p = progress(target: 1000, balance: 996);

      expect(p.percent, 99);
      expect(p.isReached, isFalse);
      expect(p.remainingCents, 4);
    });

    test('un saldo negativo cuenta como cero ahorrado', () {
      final p = progress(balance: -5000);

      expect(p.savedCents, 0);
      expect(p.remainingCents, 1000000);
      expect(p.fraction, 0);
      expect(p.percent, 0);
    });

    test('pasarse de la meta la cumple, sin pasar de 100 %', () {
      final p = progress(target: 1000000, balance: 1500000);

      expect(p.isReached, isTrue);
      expect(p.remainingCents, 0);
      expect(p.fraction, 1.0);
      expect(p.percent, 100);
    });

    test('justo el monto de la meta la cumple', () {
      expect(progress(balance: 1000000).isReached, isTrue);
    });
  });

  group('el estado', () {
    test('sin fecha, mientras falta, se sigue ahorrando', () {
      expect(progress(balance: 1).statusOn(today), GoalStatus.saving);
    });

    test('el día de la fecha todavía hay tiempo; al día siguiente, venció', () {
      final p = progress(date: today);

      expect(p.statusOn(today), GoalStatus.saving);
      expect(p.statusOn(today.add(const Duration(days: 1))), GoalStatus.overdue);
    });

    test('cumplida gana sobre vencida', () {
      final p = progress(balance: 1000000, date: DateTime(2026, 1, 1));

      expect(p.statusOn(today), GoalStatus.reached);
    });
  });

  group('los días y los meses', () {
    test('daysLeft cuenta días de calendario, sin importar la hora', () {
      final p = progress(date: DateTime(2026, 11, 5));

      expect(p.daysLeft(DateTime(2026, 10, 26, 23, 59)), 10);
      expect(p.daysLeft(DateTime(2026, 11, 5)), 0);
      expect(p.daysLeft(DateTime(2026, 11, 8)), -3);
      expect(progress().daysLeft(today), isNull);
    });

    test('monthsLeft son meses enteros, al menos uno', () {
      int? months(DateTime from, DateTime to) =>
          progress(date: to).monthsLeft(from);

      expect(months(today, DateTime(2027, 1, 26)), 3);
      expect(months(today, DateTime(2027, 1, 25)), 2);
      expect(months(today, DateTime(2026, 11, 20)), 1);
      expect(months(today, today), 1);
      expect(months(DateTime(2026, 12, 15), DateTime(2027, 2, 15)), 2);
      expect(months(today, DateTime(2028, 10, 26)), 24);
      expect(progress().monthsLeft(today), isNull);
    });

    test('el ahorro mensual se redondea hacia arriba, a la unidad entera', () {
      final p = progress(target: 1000000, date: DateTime(2027, 1, 26));

      // $10.000 en 3 meses = $3.333,33…: se pide $3.334, que sí alcanza.
      expect(p.monthlyCentsNeeded(today), 333400);
      expect(p.monthlyCentsNeeded(today)! * 3, greaterThanOrEqualTo(1000000));
    });

    test('lo que divide justo no se infla', () {
      final p = progress(target: 900000, date: DateTime(2027, 1, 26));

      expect(p.monthlyCentsNeeded(today), 300000);
    });

    test('nunca se pide más de lo que falta', () {
      // Faltan $0,40 en 3 meses: pedir $1 al mes sería más que la meta.
      final p = progress(target: 1000, balance: 960, date: DateTime(2027, 1, 26));

      expect(p.remainingCents, 40);
      expect(p.monthlyCentsNeeded(today), 40);
    });

    test('cuenta solo lo que falta', () {
      final p = progress(
        target: 1000000,
        balance: 400000,
        date: DateTime(2027, 1, 26),
      );

      expect(p.monthlyCentsNeeded(today), 200000);
    });

    test('no hay ahorro mensual si ya se llegó, si venció o si no hay fecha', () {
      expect(
        progress(balance: 1000000, date: DateTime(2027, 1, 26))
            .monthlyCentsNeeded(today),
        isNull,
      );
      expect(
        progress(date: DateTime(2026, 9, 1)).monthlyCentsNeeded(today),
        isNull,
      );
      expect(progress().monthlyCentsNeeded(today), isNull);
    });
  });

  group('el orden', () {
    test('las que vencen antes, primero; sin fecha, por nombre; cumplidas, al final', () {
      final list = [
        progress(name: 'Zapatos'),
        progress(name: 'Moto', date: DateTime(2027, 6, 1)),
        progress(name: 'Casa', balance: 1000000, date: DateTime(2026, 11, 1)),
        progress(name: 'Viaje', date: DateTime(2026, 12, 1)),
        progress(name: 'Carro'),
      ]..sort((a, b) => compareGoals(a, b, today));

      expect([for (final p in list) p.goal.name], [
        'Viaje',
        'Moto',
        'Carro',
        'Zapatos',
        'Casa',
      ]);
    });

    test('el nombre no distingue mayúsculas', () {
      final list = [progress(name: 'beta'), progress(name: 'Alfa')]
        ..sort((a, b) => compareGoals(a, b, today));

      expect(list.first.goal.name, 'Alfa');
    });
  });

  group('la meta', () {
    test('se lee de la base: el monto pasa a centavos', () {
      final goal = SavingsGoal.fromJson({
        'id': 'g1',
        'name': 'Viaje',
        'target_amount': 5000000.5,
        'account_id': 'a1',
        'target_date': '2027-03-01',
        'is_archived': false,
      });

      expect(goal.targetCents, 500000050);
      expect(goal.targetDate, DateTime(2027, 3, 1));
      expect(goal.isArchived, isFalse);
    });

    test('la fecha es opcional', () {
      final goal = SavingsGoal.fromJson({
        'id': 'g1',
        'name': 'Fondo',
        'target_amount': 100,
        'account_id': 'a1',
        'target_date': null,
        'is_archived': true,
      });

      expect(goal.targetDate, isNull);
      expect(goal.isArchived, isTrue);
    });

    test('el borrador se envía con el nombre recortado y la fecha sin hora', () {
      final json = GoalDraft(
        name: '  Viaje a Japón ',
        targetAmount: '5000000.50',
        accountId: 'a1',
        targetDate: DateTime(2027, 3, 1, 15, 30),
      ).toJson();

      expect(json, {
        'name': 'Viaje a Japón',
        'target_amount': '5000000.50',
        'account_id': 'a1',
        'target_date': '2027-03-01',
      });
      expect(
        const GoalDraft(name: 'x', targetAmount: '1', accountId: 'a').toJson()['target_date'],
        isNull,
      );
    });
  });

  group('lo que cambió el saldo de una cuenta', () {
    final date = DateTime(2026, 10, 1);

    test('un ingreso entra y un gasto sale', () {
      final income = testTransaction(
        't1',
        type: TransactionType.income,
        accountId: 'a',
        amount: 1500.25,
        date: date,
      );
      final expense = testTransaction(
        't2',
        type: TransactionType.expense,
        accountId: 'a',
        amount: 300,
        date: date,
      );

      expect(accountDeltaCents(income, 'a'), 150025);
      expect(accountDeltaCents(expense, 'a'), -30000);
    });

    test('una transferencia entra en el destino y sale del origen', () {
      final transfer = testTransaction(
        't1',
        type: TransactionType.transfer,
        accountId: 'origen',
        destinationAccountId: 'meta',
        amount: 200000,
        date: date,
      );

      expect(accountDeltaCents(transfer, 'meta'), 20000000);
      expect(accountDeltaCents(transfer, 'origen'), -20000000);
      expect(accountDeltaCents(transfer, 'otra'), 0);
    });

    test('entre monedas, al destino llega lo que se acordó', () {
      final transfer = testTransaction(
        't1',
        type: TransactionType.transfer,
        accountId: 'pesos',
        destinationAccountId: 'dolares',
        amount: 400000,
        destinationAmount: 100,
        date: date,
      );

      expect(accountDeltaCents(transfer, 'dolares'), 10000);
      expect(accountDeltaCents(transfer, 'pesos'), -40000000);
    });

    test('un movimiento de otra cuenta no la toca', () {
      final expense = testTransaction(
        't1',
        type: TransactionType.expense,
        accountId: 'otra',
        amount: 10,
        date: date,
      );

      expect(accountDeltaCents(expense, 'a'), 0);
    });
  });

  group('las reglas del formulario', () {
    test('el nombre es obligatorio y no pasa de 60 letras', () async {
      final l10n = await loadL10n();

      expect(GoalValidators.name(l10n, null), isNotNull);
      expect(GoalValidators.name(l10n, '   '), isNotNull);
      expect(GoalValidators.name(l10n, 'Viaje'), isNull);
      expect(GoalValidators.name(l10n, 'a' * 60), isNull);
      expect(GoalValidators.name(l10n, 'a' * 61), isNotNull);
    });

    test('el monto tiene que ser un número mayor que cero', () async {
      final l10n = await loadL10n();

      expect(GoalValidators.target(l10n, '5.000.000'), isNull);
      expect(GoalValidators.target(l10n, '0,50'), isNull);
      expect(GoalValidators.target(l10n, ''), l10n.goalsTargetPositive);
      expect(GoalValidators.target(l10n, '0'), l10n.goalsTargetPositive);
      expect(GoalValidators.target(l10n, '-100'), l10n.goalsTargetPositive);
      expect(GoalValidators.target(l10n, 'mucho'), l10n.commonInvalidAmount);
    });

    test('en inglés el monto se escribe con punto decimal', () async {
      final l10n = await loadL10n('en');

      expect(GoalValidators.target(l10n, '5,000.50'), isNull);
      expect(GoalValidators.target(l10n, '5.000,50'), l10n.commonInvalidAmount);
    });
  });
}
