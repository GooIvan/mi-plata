// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/summary/data/summary_repository.dart';
import 'package:mi_plata/features/summary/domain/month_summary.dart';
import 'package:mi_plata/features/summary/domain/monthly_total.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';

void main() {
  group(
    'SummaryRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient betoClient;
      late SummaryRepository summary;
      late Map<String, String> categoryId; // nombre -> id

      final march = DateTime(2026, 3);
      final april = DateTime(2026, 4);

      setUpAll(() async {
        harness = IntegrationHarness();
        final ana = await harness.signedUpClient('ana');
        betoClient = await harness.signedUpClient('beto');
        summary = SummaryRepository(ana);

        final accounts = AccountRepository(ana);
        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '0',
        );
        await accounts.create(
          name: 'Efectivo',
          type: AccountType.cash,
          initialBalance: '0',
        );
        final all = await accounts.fetchAll();
        final Account bank = all.firstWhere((a) => a.name == 'Bancolombia');
        final Account cash = all.firstWhere((a) => a.name == 'Efectivo');
        categoryId = {
          for (final c in await CategoryRepository(ana).fetchAll()) c.name: c.id,
        };

        final transactions = TransactionRepository(ana);
        Future<void> add(
          TransactionType type,
          String amount,
          DateTime date, {
          String? category,
          Account? to,
        }) => transactions.create(
          TransactionDraft(
            type: type,
            accountId: bank.id,
            destinationAccountId: to?.id,
            categoryId: category == null ? null : categoryId[category],
            amount: amount,
            date: date,
          ),
        );

        // Marzo: el último día cuenta como marzo, no como abril.
        await add(TransactionType.income, '3000000', DateTime(2026, 3, 1), category: 'Salario');
        await add(TransactionType.expense, '500000.50', DateTime(2026, 3, 10), category: 'Mercado');
        await add(TransactionType.expense, '250000.25', DateTime(2026, 3, 31), category: 'Mercado');
        await add(TransactionType.expense, '80000', DateTime(2026, 3, 15)); // sin categoría
        // Una transferencia no es ingreso ni gasto.
        await add(TransactionType.transfer, '999999', DateTime(2026, 3, 20), to: cash);
        // Abril: el primer día cuenta como abril.
        await add(TransactionType.expense, '100000', DateTime(2026, 4, 1), category: 'Transporte');
        await add(TransactionType.income, '3200000', DateTime(2026, 4, 5), category: 'Salario');
      });

      tearDownAll(() => harness.dispose());

      test('agrupa por mes, tipo y categoría con montos exactos', () async {
        final rows = await summary.fetchMonthlyTotals(from: march, to: march);

        MonthlyTotal find(TransactionType type, String? category) =>
            rows.singleWhere(
              (r) =>
                  r.type == type &&
                  r.categoryId == (category == null ? null : categoryId[category]),
            );

        expect(rows.every((r) => r.month == march && r.currency == 'COP'), isTrue);
        expect(find(TransactionType.income, 'Salario').total, 3000000);
        // 500.000,50 + 250.000,25, en una sola fila de dos movimientos.
        final mercado = find(TransactionType.expense, 'Mercado');
        expect(mercado.total, 750000.75);
        expect(mercado.movements, 2);
        expect(find(TransactionType.expense, null).total, 80000);
      });

      test('las transferencias no aparecen', () async {
        final rows = await summary.fetchMonthlyTotals(from: march, to: april);

        expect(rows.any((r) => r.type == TransactionType.transfer), isFalse);
        // 3.000.000 + 750.000,75 + 80.000 + 100.000 + 3.200.000 (sin los 999.999)
        expect(rows.fold(0.0, (sum, r) => sum + r.total), 7130000.75);
      });

      test('el último día de un mes y el primero del siguiente no se mezclan', () async {
        final aprilRows = await summary.fetchMonthlyTotals(from: april, to: april);

        // Solo el gasto del 1 de abril y el sueldo; nada del 31 de marzo.
        expect(aprilRows, hasLength(2));
        final expense = aprilRows.singleWhere((r) => r.type == TransactionType.expense);
        expect(expense.total, 100000);
        expect(expense.categoryId, categoryId['Transporte']);
      });

      test('el rango incluye ambos extremos y deja fuera lo demás', () async {
        final both = await summary.fetchMonthlyTotals(from: march, to: april);
        expect(both.map((r) => r.month).toSet(), {march, april});

        final none = await summary.fetchMonthlyTotals(
          from: DateTime(2025, 1),
          to: DateTime(2025, 12),
        );
        expect(none, isEmpty);
      });

      test('con la calculadora da el resumen esperado del mes', () async {
        final rows = await summary.fetchMonthlyTotals(from: march, to: april);
        final result = SummaryCalculator.forMonth(rows, march);

        expect(result.incomeCents, 300000000);
        expect(result.expenseCents, 83000075); // 750.000,75 + 80.000
        expect(result.balanceCents, 216999925);
        expect(
          result.expenseByCategory.map((s) => s.kind),
          [ShareKind.category, ShareKind.uncategorized],
        );
        expect(result.expenseByCategory.first.categoryId, categoryId['Mercado']);
      });

      test('cada usuario solo ve sus totales', () async {
        expect(
          await SummaryRepository(betoClient).fetchMonthlyTotals(from: march, to: april),
          isEmpty,
        );
        await expectLater(
          SummaryRepository(harness.newClient()).fetchMonthlyTotals(from: march, to: april),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
