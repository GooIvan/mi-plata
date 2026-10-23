// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_totals.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/summary/data/summary_repository.dart';
import 'package:mi_plata/features/summary/domain/balance_history.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

void main() {
  group(
    'Evolución del dinero total contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SummaryRepository summary;
      late AccountRepository accounts;
      late Account bank;
      late Account cash;
      late Account old;

      setUpAll(() async {
        harness = IntegrationHarness();
        final ana = await harness.signedUpClient('ana');
        summary = SummaryRepository(ana);
        accounts = AccountRepository(ana);
        final transactions = TransactionRepository(ana);

        await accounts.create(name: 'Banco', type: AccountType.bank, initialBalance: '1000000', currency: 'COP');
        await accounts.create(name: 'Efectivo', type: AccountType.cash, initialBalance: '50000', currency: 'COP');
        await accounts.create(name: 'Vieja', type: AccountType.bank, initialBalance: '12345', currency: 'COP');
        final all = await accounts.fetchAll();
        bank = all.firstWhere((a) => a.name == 'Banco');
        cash = all.firstWhere((a) => a.name == 'Efectivo');
        old = all.firstWhere((a) => a.name == 'Vieja');

        Future<void> add(
          TransactionType type,
          Account from,
          String amount,
          DateTime date, {
          Account? to,
        }) => transactions.create(
          TransactionDraft(
            type: type,
            accountId: from.id,
            destinationAccountId: to?.id,
            amount: amount,
            date: date,
          ),
        );

        await add(TransactionType.income, bank, '500000', DateTime(2026, 1, 10));
        await add(TransactionType.expense, bank, '120000.50', DateTime(2026, 1, 31));
        await add(TransactionType.expense, bank, '30000', DateTime(2026, 2, 1));
        await add(TransactionType.transfer, bank, '200000', DateTime(2026, 2, 15), to: cash);
        await add(TransactionType.expense, cash, '25000', DateTime(2026, 3, 2));
        await add(TransactionType.transfer, bank, '75000', DateTime(2026, 3, 10), to: old);

        await accounts.setArchived(old.id, isArchived: true);
      });

      tearDownAll(() => harness.dispose());

      test('agrupa por mes y cuenta: una transferencia resta en el origen y suma en el destino', () async {
        final flows = await summary.fetchAccountFlows();

        int cents(DateTime month, Account account) => flows
            .where((f) => f.month == month && f.accountId == account.id)
            .fold(0, (sum, f) => sum + f.cents);

        expect(cents(DateTime(2026, 1), bank), 37999950); // 500.000 - 120.000,50
        expect(cents(DateTime(2026, 2), bank), -23000000); // -30.000 - 200.000
        expect(cents(DateTime(2026, 2), cash), 20000000); // +200.000
        expect(cents(DateTime(2026, 3), cash), -2500000);
        expect(cents(DateTime(2026, 3), bank), -7500000); // -75.000
        expect(cents(DateTime(2026, 3), old), 7500000); // +75.000
        expect(flows.every((f) => f.currency == 'COP'), isTrue);
      });

      test('reconstruye el dinero al cierre de cada mes, sin las cuentas archivadas', () async {
        final points = BalanceHistory.compute(
          accounts: await accounts.fetchAll(),
          flows: await summary.fetchAccountFlows(),
          end: DateTime(2026, 3),
          months: 3,
         converter: copConverter,
        );

        expect(points.map((p) => p.cents), [
          142999950, // 1.050.000 + 500.000 - 120.000,50
          139999950, // - 30.000 (la transferencia no cambia el total)
          129999950, // - 25.000 y - 75.000 que se fueron a la cuenta archivada
        ]);
      });

      test('el último punto coincide con la suma de los saldos que calcula la base', () async {
        final all = await accounts.fetchAll();
        final points = BalanceHistory.compute(
          accounts: all,
          flows: await summary.fetchAccountFlows(),
          end: DateTime(2026, 3),
          months: 3,
         converter: copConverter,
        );

        final panelTotal = AccountTotals.centsByCurrency(
          all.where((a) => !a.isArchived),
        )['COP'];
        expect(points.last.cents, panelTotal);
      });

      test('mirando un mes anterior, no entra lo que ocurrió después', () async {
        final points = BalanceHistory.compute(
          accounts: await accounts.fetchAll(),
          flows: await summary.fetchAccountFlows(),
          end: DateTime(2026, 1),
          months: 1,
         converter: copConverter,
        );

        expect(points.single.cents, 142999950);
      });

      test('otro usuario no ve los flujos', () async {
        final beto = SummaryRepository(await harness.signedUpClient('beto'));

        expect(await beto.fetchAccountFlows(), isEmpty);
      });

      test('sin sesión falla', () async {
        await expectLater(
          SummaryRepository(harness.newClient()).fetchAccountFlows(),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
