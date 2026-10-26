// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/savings/data/savings_goal_repository.dart';
import 'package:mi_plata/features/savings/domain/goal_draft.dart';
import 'package:mi_plata/features/savings/domain/goal_progress.dart';
import 'package:mi_plata/features/savings/presentation/goal_error_message.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

late AppLocalizations l10n;

Matcher failsWith(String code, [String? details]) => throwsA(
  isA<PostgrestException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.details, 'detalle', details ?? anything),
);

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group(
    'Metas de ahorro contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      /// Un usuario nuevo con una cuenta de ahorros, una para pagar, una
      /// tarjeta y una cuenta en dólares.
      Future<
        ({
          SupabaseClient client,
          SavingsGoalRepository goals,
          AccountRepository accounts,
          TransactionRepository transactions,
          Account savings,
          Account bank,
          Account card,
          Account dollars,
        })
      >
      newUser(String prefix) async {
        final client = await harness.signedUpClient(prefix);
        final accounts = AccountRepository(client);
        Future<void> create(
          String name,
          AccountType type,
          String balance, [
          String currency = 'COP',
        ]) => accounts.create(
          name: name,
          type: type,
          initialBalance: balance,
          currency: currency,
        );
        await create('Ahorros', AccountType.bank, '1000000');
        await create('Bancolombia', AccountType.bank, '5000000');
        await create('Visa', AccountType.card, '0');
        await create('Dólares', AccountType.bank, '100', 'USD');
        final all = await accounts.fetchAll();
        Account named(String name) => all.firstWhere((a) => a.name == name);
        return (
          client: client,
          goals: SavingsGoalRepository(client),
          accounts: accounts,
          transactions: TransactionRepository(client),
          savings: named('Ahorros'),
          bank: named('Bancolombia'),
          card: named('Visa'),
          dollars: named('Dólares'),
        );
      }

      GoalDraft draft(
        Account account, {
        String name = 'Viaje a Japón',
        String target = '5000000',
        DateTime? date,
      }) => GoalDraft(
        name: name,
        targetAmount: target,
        accountId: account.id,
        targetDate: date,
      );

      test('crea una meta y la lee con su cuenta, monto y fecha', () async {
        final ana = await newUser('goal-create');

        await ana.goals.create(
          draft(ana.savings, name: '  Viaje a Japón ', target: '5000000.50',
              date: DateTime(2027, 3, 1)),
        );

        final goal = (await ana.goals.fetchAll()).single;
        expect(goal.name, 'Viaje a Japón');
        expect(goal.targetCents, 500000050);
        expect(goal.accountId, ana.savings.id);
        expect(goal.targetDate, DateTime(2027, 3, 1));
        expect(goal.isArchived, isFalse);
      });

      test('la fecha es opcional', () async {
        final ana = await newUser('goal-nodate');

        await ana.goals.create(draft(ana.savings));

        expect((await ana.goals.fetchAll()).single.targetDate, isNull);
      });

      test('lo ahorrado es el saldo de la cuenta: sube con una transferencia', () async {
        final ana = await newUser('goal-progress');
        await ana.goals.create(draft(ana.savings));

        await ana.transactions.create(
          TransactionDraft(
            type: TransactionType.transfer,
            accountId: ana.bank.id,
            destinationAccountId: ana.savings.id,
            amount: '500000',
            date: DateTime(2026, 10, 1),
          ),
        );

        final account = (await ana.accounts.fetchAll())
            .firstWhere((a) => a.id == ana.savings.id);
        final progress = GoalProgress(
          goal: (await ana.goals.fetchAll()).single,
          accountName: account.name,
          currency: account.currency,
          balanceCents: (account.currentBalance * 100).round(),
        );
        // 1.000.000 iniciales + 500.000 de la transferencia.
        expect(progress.savedCents, 150000000);
        expect(progress.percent, 30);
        expect(progress.remainingCents, 350000000);
      });

      test('sacar plata de la cuenta baja el avance', () async {
        final ana = await newUser('goal-withdraw');
        await ana.goals.create(draft(ana.savings));

        await ana.transactions.create(
          TransactionDraft(
            type: TransactionType.transfer,
            accountId: ana.savings.id,
            destinationAccountId: ana.bank.id,
            amount: '400000',
            date: DateTime(2026, 10, 1),
          ),
        );

        final account = (await ana.accounts.fetchAll())
            .firstWhere((a) => a.id == ana.savings.id);
        expect(account.currentBalance, 600000);
      });

      test('una meta en dólares se mide en dólares, con lo que llega a la cuenta', () async {
        final ana = await newUser('goal-usd');
        await ana.goals.create(draft(ana.dollars, name: 'Laptop', target: '1500'));

        await ana.transactions.create(
          TransactionDraft(
            type: TransactionType.transfer,
            accountId: ana.bank.id,
            destinationAccountId: ana.dollars.id,
            amount: '400000',
            destinationAmount: '100',
            date: DateTime(2026, 10, 1),
          ),
        );

        final account = (await ana.accounts.fetchAll())
            .firstWhere((a) => a.id == ana.dollars.id);
        // 100 USD iniciales + 100 USD que llegaron, no 400.000.
        expect(account.currentBalance, 200);
        expect(account.currency, 'USD');
      });

      group('las reglas', () {
        test('una tarjeta no puede ser la cuenta de una meta', () async {
          final ana = await newUser('goal-card');

          await expectLater(
            ana.goals.create(draft(ana.card)),
            failsWith('23514', 'goal_account_card'),
          );
          try {
            await ana.goals.create(draft(ana.card));
          } catch (error) {
            expect(
              goalErrorMessage(l10n, error),
              'Una tarjeta no puede ser la cuenta de una meta de ahorro',
            );
          }
          expect(await ana.goals.fetchAll(), isEmpty);
        });

        test('tampoco se puede cambiar la cuenta de una meta a una tarjeta', () async {
          final ana = await newUser('goal-card-update');
          await ana.goals.create(draft(ana.savings));
          final goal = (await ana.goals.fetchAll()).single;

          await expectLater(
            ana.goals.update(goal.id, draft(ana.card)),
            failsWith('23514', 'goal_account_card'),
          );
        });

        test('una cuenta tiene una sola meta activa', () async {
          final ana = await newUser('goal-one');
          await ana.goals.create(draft(ana.savings));

          await expectLater(
            ana.goals.create(draft(ana.savings, name: 'Otra')),
            failsWith('23505'),
          );
          try {
            await ana.goals.create(draft(ana.savings, name: 'Otra'));
          } catch (error) {
            expect(goalErrorMessage(l10n, error), l10n.goalsErrorAccountTaken);
          }
          expect(await ana.goals.fetchAll(), hasLength(1));
        });

        test('al archivar una meta, su cuenta queda libre para otra', () async {
          final ana = await newUser('goal-archive');
          await ana.goals.create(draft(ana.savings));
          final first = (await ana.goals.fetchAll()).single;

          await ana.goals.setArchived(first.id, isArchived: true);
          await ana.goals.create(draft(ana.savings, name: 'Moto'));

          final all = await ana.goals.fetchAll();
          expect(all, hasLength(2));
          expect(all.where((g) => !g.isArchived).single.name, 'Moto');
        });

        test('no se restaura una meta si su cuenta ya tiene otra activa', () async {
          final ana = await newUser('goal-restore');
          await ana.goals.create(draft(ana.savings));
          final first = (await ana.goals.fetchAll()).single;
          await ana.goals.setArchived(first.id, isArchived: true);
          await ana.goals.create(draft(ana.savings, name: 'Moto'));

          await expectLater(
            ana.goals.setArchived(first.id, isArchived: false),
            failsWith('23505'),
          );
        });

        test('se pueden tener varias metas archivadas en la misma cuenta', () async {
          final ana = await newUser('goal-many-archived');
          for (final name in ['Uno', 'Dos', 'Tres']) {
            await ana.goals.create(draft(ana.savings, name: name));
            final goal = (await ana.goals.fetchAll()).firstWhere((g) => g.name == name);
            await ana.goals.setArchived(goal.id, isArchived: true);
          }

          expect((await ana.goals.fetchAll()).where((g) => g.isArchived), hasLength(3));
        });

        test('el monto tiene que ser mayor que cero y el nombre no puede estar vacío', () async {
          final ana = await newUser('goal-checks');

          for (final target in ['0', '-100']) {
            await expectLater(
              ana.goals.create(draft(ana.savings, target: target)),
              failsWith('23514'),
            );
          }
          await expectLater(
            ana.goals.create(draft(ana.savings, name: '   ')),
            failsWith('23514'),
          );
          try {
            await ana.goals.create(draft(ana.savings, target: '0'));
          } catch (error) {
            expect(goalErrorMessage(l10n, error), l10n.goalsErrorInvalid);
          }
        });

        test('el monto cabe en numeric(14,2): no se acepta más', () async {
          final ana = await newUser('goal-big');

          await expectLater(
            ana.goals.create(draft(ana.savings, target: '1000000000000')),
            throwsA(isA<PostgrestException>()),
          );
        });
      });

      group('edición', () {
        test('se cambian el nombre, el monto y la fecha', () async {
          final ana = await newUser('goal-edit');
          await ana.goals.create(draft(ana.savings, date: DateTime(2027, 3, 1)));
          final goal = (await ana.goals.fetchAll()).single;

          await ana.goals.update(
            goal.id,
            draft(ana.savings, name: 'Japón 2027', target: '6000000'),
          );

          final saved = (await ana.goals.fetchAll()).single;
          expect(saved.name, 'Japón 2027');
          expect(saved.targetCents, 600000000);
          expect(saved.targetDate, isNull);
        });

        test('editar una meta no cambia el estado de archivada', () async {
          final ana = await newUser('goal-edit-archived');
          await ana.goals.create(draft(ana.savings));
          final goal = (await ana.goals.fetchAll()).single;
          await ana.goals.setArchived(goal.id, isArchived: true);
          await ana.goals.create(draft(ana.savings, name: 'Moto'));

          // La archivada se edita sin chocar con la activa de la misma cuenta.
          await ana.goals.update(goal.id, draft(ana.savings, name: 'Vieja'));

          final all = await ana.goals.fetchAll();
          expect(all.firstWhere((g) => g.id == goal.id).isArchived, isTrue);
          expect(all.firstWhere((g) => g.id == goal.id).name, 'Vieja');
        });
      });

      group('seguridad', () {
        test('cada usuario ve solo sus metas', () async {
          final ana = await newUser('goal-ana');
          final beto = await newUser('goal-beto');
          await ana.goals.create(draft(ana.savings, name: 'De Ana'));
          await beto.goals.create(draft(beto.savings, name: 'De Beto'));

          expect((await ana.goals.fetchAll()).single.name, 'De Ana');
          expect((await beto.goals.fetchAll()).single.name, 'De Beto');
        });

        test('no se puede crear una meta sobre la cuenta de otro usuario', () async {
          final ana = await newUser('goal-owner');
          final beto = await newUser('goal-intruder');

          await expectLater(
            beto.goals.create(draft(ana.savings)),
            failsWith('23503'),
          );
          try {
            await beto.goals.create(draft(ana.savings));
          } catch (error) {
            expect(goalErrorMessage(l10n, error), l10n.goalsErrorMissingAccount);
          }
        });

        test('no se pueden tocar las metas de otro usuario', () async {
          final ana = await newUser('goal-victim');
          final beto = await newUser('goal-attacker');
          await ana.goals.create(draft(ana.savings, name: 'De Ana'));
          final goal = (await ana.goals.fetchAll()).single;

          await beto.goals.update(goal.id, draft(beto.savings, name: 'Robada'));
          await beto.goals.setArchived(goal.id, isArchived: true);

          final intact = (await ana.goals.fetchAll()).single;
          expect(intact.name, 'De Ana');
          expect(intact.isArchived, isFalse);
          expect(intact.accountId, ana.savings.id);
        });

        test('sin sesión no se ve ni se hace nada', () async {
          final anonymous = SavingsGoalRepository(harness.newClient());

          await expectLater(anonymous.fetchAll(), throwsA(isA<PostgrestException>()));
          await expectLater(
            anonymous.create(
              const GoalDraft(
                name: 'x',
                targetAmount: '1',
                accountId: '00000000-0000-0000-0000-000000000000',
              ),
            ),
            throwsA(isA<PostgrestException>()),
          );
        });
      });
    },
  );
}
