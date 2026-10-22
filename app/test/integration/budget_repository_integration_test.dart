// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/budgets/data/budget_repository.dart';
import 'package:mi_plata/features/budgets/domain/budget_calculator.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/summary/data/summary_repository.dart';
import 'package:mi_plata/features/summary/domain/month_summary.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';

void main() {
  group(
    'BudgetRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient anaClient;
      late SupabaseClient betoClient;
      late BudgetRepository budgets;
      late String expenseId; // una categoría de gasto de Ana
      late String otherExpenseId;
      late String incomeId;

      final march = DateTime(2026, 3);
      final april = DateTime(2026, 4);

      setUpAll(() async {
        harness = IntegrationHarness();
        anaClient = await harness.signedUpClient('ana');
        betoClient = await harness.signedUpClient('beto');
        budgets = BudgetRepository(anaClient);

        final categories = await CategoryRepository(anaClient).fetchAll();
        final expenses = categories.where(
          (c) => c.type == CategoryType.expense,
        );
        expenseId = expenses.first.id;
        otherExpenseId = expenses.last.id;
        incomeId = categories
            .firstWhere((c) => c.type == CategoryType.income)
            .id;
        expect(expenseId, isNot(otherExpenseId));
      });

      tearDownAll(() => harness.dispose());

      Future<List<int>> centsOf(String categoryId) async => [
        for (final rule in await budgets.fetchAll())
          if (rule.categoryId == categoryId) rule.cents,
      ];

      test('sin presupuestos, no hay reglas', () async {
        expect(await budgets.fetchAll(), isEmpty);
      });

      test(
        'define un presupuesto desde un mes, con decimales exactos',
        () async {
          await budgets.set(
            categoryId: otherExpenseId,
            month: march,
            amount: '1500.50',
          );

          final rule = (await budgets.fetchAll()).single;
          expect(rule.categoryId, otherExpenseId);
          expect(rule.month, march);
          expect(rule.cents, 150050);
        },
      );

      test('definirlo otra vez en el mismo mes lo reemplaza', () async {
        await budgets.set(
          categoryId: expenseId,
          month: march,
          amount: '500000',
        );
        await budgets.set(
          categoryId: expenseId,
          month: march,
          amount: '650000',
        );

        expect(await centsOf(expenseId), [65000000]);
      });

      test('otro mes agrega una regla; las dos conviven', () async {
        await budgets.set(
          categoryId: expenseId,
          month: april,
          amount: '800000',
        );

        final rules = (await budgets.fetchAll())
            .where((r) => r.categoryId == expenseId)
            .toList();
        expect(rules, hasLength(2));

        // Marzo conserva lo suyo y abril usa lo nuevo.
        final all = await budgets.fetchAll();
        expect(
          BudgetCalculator.effectiveLimits(all, march)[expenseId],
          65000000,
        );
        expect(
          BudgetCalculator.effectiveLimits(all, april)[expenseId],
          80000000,
        );
        // Un mes anterior al primer presupuesto no tiene ninguno.
        expect(
          BudgetCalculator.effectiveLimits(all, DateTime(2026, 2)),
          isNot(contains(expenseId)),
        );
      });

      test(
        'con monto 0 la regla queda y significa "sin presupuesto"',
        () async {
          await budgets.set(
            categoryId: expenseId,
            month: DateTime(2026, 5),
            amount: '0',
          );

          final all = await budgets.fetchAll();
          expect(
            BudgetCalculator.effectiveLimits(all, DateTime(2026, 5)),
            isNot(contains(expenseId)),
          );
          // Pero los meses anteriores no cambian.
          expect(
            BudgetCalculator.effectiveLimits(all, april)[expenseId],
            80000000,
          );
        },
      );

      test('el día del mes se normaliza al primero', () async {
        await budgets.set(
          categoryId: expenseId,
          month: DateTime(2026, 6, 23),
          amount: '1000',
        );

        final rule = (await budgets.fetchAll()).firstWhere(
          (r) => r.categoryId == expenseId && r.month == DateTime(2026, 6),
        );
        expect(rule.cents, 100000);
      });

      group('la base de datos rechaza', () {
        Future<PostgrestException> failureOf(Future<void> action) async {
          try {
            await action;
          } on PostgrestException catch (error) {
            return error;
          }
          fail('debía fallar');
        }

        test(
          'presupuestos de categorías de ingreso, con un mensaje claro',
          () async {
            final error = await failureOf(
              budgets.set(categoryId: incomeId, month: march, amount: '1000'),
            );
            expect(error.code, '23514');
            expect(
              error.message,
              'Solo las categorías de gasto pueden tener presupuesto',
            );
          },
        );

        test('montos negativos', () async {
          final error = await failureOf(
            budgets.set(categoryId: expenseId, month: march, amount: '-1'),
          );
          expect(error.code, '23514');
        });

        test('un mes que no empieza el día 1', () async {
          final error = await failureOf(
            anaClient.from('budgets').insert({
              'category_id': expenseId,
              'effective_month': '2026-07-15',
              'amount': '1000',
            }),
          );
          expect(error.code, '23514');
        });

        test('categorías que no existen', () async {
          final error = await failureOf(
            budgets.set(
              categoryId: '00000000-0000-0000-0000-000000000000',
              month: march,
              amount: '1000',
            ),
          );
          expect(error.code, '23503');
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no ve mis presupuestos', () async {
          expect(await BudgetRepository(betoClient).fetchAll(), isEmpty);
        });

        test('otro usuario no puede presupuestar mis categorías', () async {
          // Si mi fila ya existe para ese mes, lo frena la seguridad por filas
          // (42501); si no, la llave foránea (23503): para él mi categoría no
          // existe. En ambos casos no se escribe nada.
          await expectLater(
            BudgetRepository(betoClient)
                .set(categoryId: expenseId, month: march, amount: '1'),
            throwsA(
              isA<PostgrestException>().having(
                (e) => e.code,
                'code',
                anyOf('42501', '23503'),
              ),
            ),
          );
          await expectLater(
            BudgetRepository(betoClient)
                .set(categoryId: expenseId, month: DateTime(2030), amount: '1'),
            throwsA(
              isA<PostgrestException>().having((e) => e.code, 'code', '23503'),
            ),
          );
          // Y lo mío sigue igual.
          expect(await centsOf(expenseId), contains(65000000));
        });

        test('sin sesión no se puede leer', () async {
          final anonymous = BudgetRepository(harness.newClient());
          await expectLater(
            anonymous.fetchAll(),
            throwsA(isA<PostgrestException>()),
          );
        });

        test('otro usuario no puede modificar mis filas', () async {
          // Beto intenta apropiarse de la fila de Ana.
          final stolen = await betoClient
              .from('budgets')
              .update({'amount': '1'})
              .eq('category_id', expenseId)
              .select();
          expect(stolen, isEmpty);
          expect(await centsOf(expenseId), contains(65000000));
        });
      });

      test('junto con los gastos reales, dice qué categoría se pasó', () async {
        final accounts = AccountRepository(anaClient);
        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '1000000',
        );
        final account = (await accounts.fetchAll()).single;

        // Marzo: presupuesto de 650.000; se gastan 700.000 (se pasó por 50.000)
        // y 20.000 en otra categoría sin presupuesto en marzo.
        final transactions = TransactionRepository(anaClient);
        Future<void> spend(String categoryId, String amount) =>
            transactions.create(
              TransactionDraft(
                type: TransactionType.expense,
                accountId: account.id,
                categoryId: categoryId,
                amount: amount,
                date: DateTime(2026, 3, 10),
              ),
            );
        await spend(expenseId, '400000');
        await spend(expenseId, '300000');
        await spend(
          (await CategoryRepository(anaClient).fetchAll())
              .firstWhere(
                (c) =>
                    c.type == CategoryType.expense &&
                    c.id != expenseId &&
                    c.id != otherExpenseId,
              )
              .id,
          '20000',
        );

        final totals = await SummaryRepository(anaClient)
            .fetchMonthlyTotals(from: march, to: march);
        final overview = BudgetCalculator.overview(
          rules: await budgets.fetchAll(),
          month: march,
          expenseCentsByCategory: SummaryCalculator.forMonth(
            totals,
            march,
          ).expenseCentsByCategory,
        );

        final mine = overview.budgeted.firstWhere(
          (b) => b.categoryId == expenseId,
        );
        expect(mine.limitCents, 65000000);
        expect(mine.spentCents, 70000000);
        expect(mine.status, BudgetStatus.over);
        expect(mine.remainingCents, -5000000);

        // Lo que no tiene presupuesto se muestra aparte.
        expect(overview.unbudgeted.single.spentCents, 2000000);
        // Y el presupuesto de la otra categoría (sin gastos) cuenta como "bien".
        final untouched = overview.budgeted.firstWhere(
          (b) => b.categoryId == otherExpenseId,
        );
        expect(untouched.spentCents, 0);
        expect(untouched.status, BudgetStatus.ok);
      });
    },
  );
}
