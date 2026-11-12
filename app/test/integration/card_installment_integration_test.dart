// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/errors/database_error.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/data/card_installment_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/card_installment_draft.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group(
    'Compras en cuotas con tarjeta contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late AccountRepository accounts;
      late TransactionRepository transactions;
      late CardInstallmentRepository installments;
      late Account card;
      late Account bank;
      final date = DateTime(2026, 10, 20);

      Future<Account> create(String name, AccountType type) async {
        await accounts.create(
          name: name,
          type: type,
          initialBalance: '0',
          currency: 'COP',
          statementDay: type == AccountType.card ? 15 : null,
          paymentDay: type == AccountType.card ? 30 : null,
        );
        return (await accounts.fetchAll()).firstWhere((a) => a.name == name);
      }

      Future<double> balanceOf(Account account) async =>
          (await accounts.fetchAll())
              .firstWhere((a) => a.id == account.id)
              .currentBalance;

      CardInstallmentDraft purchase({
        required String amount,
        required int count,
        String? each,
        String? accountId,
        String? description = 'Televisor',
      }) => CardInstallmentDraft(
        accountId: accountId ?? card.id,
        purchaseAmount: amount,
        installments: count,
        installmentAmount: each,
        date: date,
        description: description,
      );

      setUpAll(() async {
        harness = IntegrationHarness();
        final client = await harness.signedUpClient('cuotas');
        accounts = AccountRepository(client);
        transactions = TransactionRepository(client);
        installments = CardInstallmentRepository(client);
        card = await create('Visa', AccountType.card);
        bank = await create('Banco', AccountType.bank);
      });

      tearDownAll(() => harness.dispose());

      test(
        'sin valor de cuota no hay intereses: el gasto es por la compra',
        () async {
          final before = await balanceOf(card);
          await installments.createPurchase(
            purchase(
              amount: '1200000',
              count: 12,
              description: 'Sin intereses',
            ),
          );

          final plan = (await installments.fetchAll()).firstWhere(
            (p) => p.description == 'Sin intereses',
          );
          expect(plan.accountId, card.id);
          expect(plan.date, date);
          expect(plan.installments, 12);
          expect(plan.purchaseCents, 120000000);
          expect(plan.totalCents, 120000000);
          expect(plan.installmentCents, 10000000);
          expect(plan.interestCents, 0);
          // Es un gasto de la tarjeta: la deuda sube de una vez.
          expect(await balanceOf(card), before - 1200000);
        },
      );

      test(
        'con valor de cuota, el gasto es por el total con intereses',
        () async {
          final before = await balanceOf(card);
          await installments.createPurchase(
            purchase(
              amount: '1200000',
              count: 12,
              each: '125000',
              description: 'Con intereses',
            ),
          );

          final plan = (await installments.fetchAll()).firstWhere(
            (p) => p.description == 'Con intereses',
          );
          expect(plan.purchaseCents, 120000000);
          expect(plan.totalCents, 150000000);
          expect(plan.interestCents, 30000000);
          expect(plan.installmentCents, 12500000);
          expect(await balanceOf(card), before - 1500000);
        },
      );

      test('los centavos de una compra que no se parte exacto los absorbe la última', () async {
        await installments.createPurchase(
          purchase(amount: '100000', count: 3, description: 'Centavos'),
        );

        final plan = (await installments.fetchAll()).firstWhere(
          (p) => p.description == 'Centavos',
        );
        expect(plan.installmentCents, 3333333);
        expect(plan.totalCents, 10000000);
        expect(plan.cuotaCents(3), 3333334);
      });

      test('solo una tarjeta se puede diferir', () async {
        await expectLater(
          installments.createPurchase(
            purchase(amount: '100000', count: 3, accountId: bank.id),
          ),
          throwsA(
            isA<PostgrestException>()
                .having((e) => e.code, 'código', '23514')
                .having(
                  (e) => databaseErrorMessage(l10n, e),
                  'mensaje',
                  'Solo una compra hecha con una tarjeta se puede diferir en cuotas',
                ),
          ),
        );
      });

      test(
        'cuotas que no cuadran con la compra se rechazan y no dejan nada',
        () async {
          final before = await balanceOf(card);
          final plansBefore = (await installments.fetchAll()).length;

          await expectLater(
            installments.createPurchase(
              purchase(amount: '1200000', count: 12, each: '100'),
            ),
            throwsA(
              isA<PostgrestException>().having(
                (e) => e.details,
                'detalle',
                'installment_purchase_amounts',
              ),
            ),
          );

          // Todo o nada: ni gasto ni plan.
          expect(await balanceOf(card), before);
          expect((await installments.fetchAll()).length, plansBefore);
        },
      );

      test('el número de cuotas va de 2 a 60', () async {
        for (final count in [1, 61]) {
          await expectLater(
            installments.createPurchase(
              purchase(amount: '100000', count: count),
            ),
            throwsA(
              isA<PostgrestException>().having(
                (e) => e.code,
                'código',
                '23514',
              ),
            ),
          );
        }
      });

      test('una cuenta que no existe da un error que se traduce', () async {
        await expectLater(
          installments.createPurchase(
            purchase(
              amount: '100000',
              count: 3,
              accountId: '00000000-0000-0000-0000-000000000000',
            ),
          ),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.details,
              'detalle',
              'account_not_found',
            ),
          ),
        );
      });

      group('el gasto de una compra diferida', () {
        late String transactionId;

        setUpAll(() async {
          await installments.createPurchase(
            purchase(amount: '600000', count: 6, description: 'Bloqueada'),
          );
          transactionId = (await installments.fetchAll())
              .firstWhere((p) => p.description == 'Bloqueada')
              .transactionId;
        });

        TransactionDraft draft({
          String? amount,
          String? accountId,
          TransactionType type = TransactionType.expense,
          String description = 'Bloqueada',
          DateTime? at,
        }) => TransactionDraft(
          type: type,
          accountId: accountId ?? card.id,
          amount: amount ?? '600000',
          date: at ?? date,
          description: description,
        );

        test('no cambia de monto, de cuenta ni de tipo', () async {
          for (final changed in [
            draft(amount: '500000'),
            draft(accountId: bank.id),
            draft(type: TransactionType.income),
          ]) {
            await expectLater(
              transactions.update(transactionId, changed),
              throwsA(
                isA<PostgrestException>()
                    .having((e) => e.code, 'código', '23514')
                    .having(
                      (e) => e.details,
                      'detalle',
                      'installment_purchase_locked',
                    ),
              ),
            );
          }
        });

        test('sí cambia de descripción y de fecha', () async {
          await transactions.update(
            transactionId,
            draft(description: 'Renombrada', at: DateTime(2026, 10, 25)),
          );

          final plan = (await installments.fetchAll()).firstWhere(
            (p) => p.transactionId == transactionId,
          );
          expect(plan.description, 'Renombrada');
          expect(plan.date, DateTime(2026, 10, 25));
        });

        test('al borrarlo se borra su plan', () async {
          await transactions.delete(transactionId);

          expect(
            (await installments.fetchAll()).where(
              (p) => p.transactionId == transactionId,
            ),
            isEmpty,
          );
        });
      });

      test('cada usuario solo ve sus compras en cuotas', () async {
        final other = await harness.signedUpClient('otra-persona');
        expect(await CardInstallmentRepository(other).fetchAll(), isEmpty);
        // Ni diferir una compra con la tarjeta de otro.
        await expectLater(
          CardInstallmentRepository(other)
              .createPurchase(purchase(amount: '100000', count: 3)),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          CardInstallmentRepository(harness.newClient()).fetchAll(),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
