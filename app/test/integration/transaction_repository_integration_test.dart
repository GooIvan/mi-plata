// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_app.dart';

import '../support/integration_harness.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group(
    'TransactionRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient betoClient;
      late AccountRepository accounts;
      late CategoryRepository categories;
      late TransactionRepository transactions;

      late Account bancolombia;
      late Account efectivo;
      late Map<String, Category> category;

      Future<double> balanceOf(Account account) async =>
          (await accounts.fetchAll())
              .firstWhere((a) => a.id == account.id)
              .currentBalance;

      TransactionDraft draft(
        TransactionType type, {
        required Account from,
        Account? to,
        String? categoryName,
        String amount = '1000',
        DateTime? date,
        String? description,
      }) => TransactionDraft(
        type: type,
        accountId: from.id,
        destinationAccountId: to?.id,
        categoryId: categoryName == null ? null : category[categoryName]!.id,
        amount: amount,
        date: date ?? DateTime(2026, 10, 22),
        description: description,
      );

      setUpAll(() async {
        harness = IntegrationHarness();
        final ana = await harness.signedUpClient('ana');
        betoClient = await harness.signedUpClient('beto');
        accounts = AccountRepository(ana);
        categories = CategoryRepository(ana);
        transactions = TransactionRepository(ana);

        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '1000000',
        );
        await accounts.create(
          name: 'Efectivo',
          type: AccountType.cash,
          initialBalance: '50000',
        );
        final all = await accounts.fetchAll();
        bancolombia = all.firstWhere((a) => a.name == 'Bancolombia');
        efectivo = all.firstWhere((a) => a.name == 'Efectivo');
        category = {for (final c in await categories.fetchAll()) c.name: c};
      });

      tearDownAll(() => harness.dispose());

      test('cada usuario nuevo recibe las categorías por defecto', () {
        expect(category, hasLength(13));
        expect(category['Salario']!.type, CategoryType.income);
        expect(category['Mercado']!.type, CategoryType.expense);
      });

      test('ingreso, gasto y transferencia mueven los saldos', () async {
        await transactions.create(
          draft(
            TransactionType.income,
            from: bancolombia,
            categoryName: 'Salario',
            amount: '500000',
            date: DateTime(2026, 10, 20),
          ),
        );
        await transactions.create(
          draft(
            TransactionType.expense,
            from: bancolombia,
            categoryName: 'Mercado',
            amount: '120000.50',
            date: DateTime(2026, 10, 21),
            description: 'Compra semanal',
          ),
        );
        await transactions.create(
          draft(
            TransactionType.transfer,
            from: bancolombia,
            to: efectivo,
            amount: '200000',
            date: DateTime(2026, 10, 22),
          ),
        );

        // 1.000.000 + 500.000 - 120.000,50 - 200.000
        expect(await balanceOf(bancolombia), 1179999.5);
        // 50.000 + 200.000
        expect(await balanceOf(efectivo), 250000);

        final recent = await transactions.fetchRecent();
        expect(recent, hasLength(3));
        // Los más recientes primero.
        expect(recent.map((t) => t.type), [
          TransactionType.transfer,
          TransactionType.expense,
          TransactionType.income,
        ]);
        expect(recent[0].destinationAccountId, efectivo.id);
        expect(recent[0].categoryId, isNull);
        expect(recent[1].amount, 120000.5);
        expect(recent[1].description, 'Compra semanal');
        expect(recent[1].date, DateTime(2026, 10, 21));
      });

      test('editar cambia el monto, y pasar a gasto limpia el destino', () async {
        final transfer = (await transactions.fetchRecent()).first;
        expect(transfer.type, TransactionType.transfer);

        await transactions.update(
          transfer.id,
          draft(
            TransactionType.expense,
            from: bancolombia,
            categoryName: 'Transporte',
            amount: '30000',
            date: DateTime(2026, 10, 22),
          ),
        );

        final edited = (await transactions.fetchRecent()).first;
        expect(edited.id, transfer.id);
        expect(edited.type, TransactionType.expense);
        expect(edited.destinationAccountId, isNull);
        expect(edited.categoryId, category['Transporte']!.id);
        // El Efectivo ya no recibe los 200.000.
        expect(await balanceOf(efectivo), 50000);
        // 1.000.000 + 500.000 - 120.000,50 - 30.000
        expect(await balanceOf(bancolombia), 1349999.5);
      });

      test('eliminar devuelve el saldo', () async {
        final expense = (await transactions.fetchRecent()).firstWhere(
          (t) => t.description == 'Compra semanal',
        );
        final before = await balanceOf(bancolombia);

        await transactions.delete(expense.id);

        expect(await balanceOf(bancolombia), before + 120000.5);
        expect(
          (await transactions.fetchRecent()).where((t) => t.id == expense.id),
          isEmpty,
        );
      });

      group('la base de datos rechaza lo inválido', () {
        test('un monto de cero', () async {
          await expectLater(
            transactions.create(
              draft(TransactionType.expense, from: bancolombia, amount: '0'),
            ),
            failsWith('23514'),
          );
        });

        test('una transferencia a la misma cuenta o sin destino', () async {
          await expectLater(
            transactions.create(
              draft(TransactionType.transfer, from: bancolombia, to: bancolombia),
            ),
            failsWith('23514'),
          );
          await expectLater(
            transactions.create(
              draft(TransactionType.transfer, from: bancolombia),
            ),
            failsWith('23514'),
          );
        });

        test('una categoría que no corresponde, con mensaje en español', () async {
          await expectLater(
            transactions.create(
              draft(
                TransactionType.expense,
                from: bancolombia,
                categoryName: 'Salario',
              ),
            ),
            throwsA(
              isA<PostgrestException>()
                  .having((e) => e.code, 'code', '23514')
                  .having((e) => e.details, 'detalle', 'transaction_category_mismatch')
                  .having(
                    (e) => transactionErrorMessage(l10n, e),
                    'mensaje',
                    'La categoría elegida no corresponde a este tipo de movimiento',
                  ),
            ),
          );
        });

        test('una categoría en una transferencia', () async {
          await expectLater(
            transactions.create(
              draft(
                TransactionType.transfer,
                from: bancolombia,
                to: efectivo,
                categoryName: 'Mercado',
              ),
            ),
            failsWith('23514'),
          );
        });

        test('el mensaje de un CHECK no llega crudo al usuario', () async {
          try {
            await transactions.create(
              draft(TransactionType.expense, from: bancolombia, amount: '0'),
            );
            fail('debía fallar');
          } on PostgrestException catch (error) {
            expect(
              transactionErrorMessage(l10n, error),
              startsWith('Revisa los datos del movimiento'),
            );
          }
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no ve los movimientos', () async {
          expect(await transactions.fetchRecent(), isNotEmpty);
          expect(await TransactionRepository(betoClient).fetchRecent(), isEmpty);
        });

        test('otro usuario no puede usar mis cuentas', () async {
          await expectLater(
            TransactionRepository(betoClient).create(
              draft(TransactionType.expense, from: bancolombia),
            ),
            failsWith('23503'),
          );
        });

        test('otro usuario no puede editar ni borrar mis movimientos', () async {
          final mine = (await transactions.fetchRecent()).first;
          final beto = TransactionRepository(betoClient);

          // RLS no da error: simplemente no encuentra la fila.
          await beto.delete(mine.id);
          await beto.update(
            mine.id,
            draft(TransactionType.expense, from: bancolombia, amount: '1'),
          );

          final intact = (await transactions.fetchRecent()).firstWhere(
            (t) => t.id == mine.id,
          );
          expect(intact.amount, mine.amount);
        });

        test('sin sesión no se ve nada', () async {
          await expectLater(
            TransactionRepository(harness.newClient()).fetchRecent(),
            throwsA(isA<PostgrestException>()),
          );
        });
      });
    },
  );
}

Matcher failsWith(String code) => throwsA(
  isA<PostgrestException>().having((e) => e.code, 'code', code),
);
