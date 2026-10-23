// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/debts/data/debt_repository.dart';
import 'package:mi_plata/features/debts/domain/debt.dart';
import 'package:mi_plata/features/debts/domain/debt_direction.dart';
import 'package:mi_plata/features/debts/domain/debt_draft.dart';
import 'package:mi_plata/features/debts/presentation/debt_error_message.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
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
    'DebtRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient betoClient;
      late DebtRepository debts;
      late AccountRepository accounts;
      late TransactionRepository transactions;
      late Account bank;
      late Account cash;

      final start = DateTime(2026, 10, 1);

      Future<double> balanceOf(Account account) async =>
          (await accounts.fetchAll())
              .firstWhere((a) => a.id == account.id)
              .currentBalance;

      Future<Debt> debtNamed(String name) async =>
          (await debts.fetchAll()).firstWhere((d) => d.counterparty == name);

      Future<void> create(
        String name, {
        DebtDirection direction = DebtDirection.payable,
        String amount = '500000',
        Account? account,
        DateTime? due,
        String? notes,
      }) => debts.create(
        DebtDraft(
          direction: direction,
          counterparty: name,
          amount: amount,
          startDate: start,
          dueDate: due,
          notes: notes,
          accountId: account?.id,
        ),
      );

      Matcher failsWith(String code, [String? fragment]) => throwsA(
        isA<PostgrestException>()
            .having((e) => e.code, 'code', code)
            .having(
              (e) => e.message,
              'mensaje',
              fragment == null ? anything : contains(fragment),
            ),
      );

      setUpAll(() async {
        harness = IntegrationHarness();
        final ana = await harness.signedUpClient('ana');
        betoClient = await harness.signedUpClient('beto');
        debts = DebtRepository(ana);
        accounts = AccountRepository(ana);
        transactions = TransactionRepository(ana);

        await accounts.create(name: 'Bancolombia', type: AccountType.bank, initialBalance: '1000000');
        await accounts.create(name: 'Efectivo', type: AccountType.cash, initialBalance: '50000');
        final all = await accounts.fetchAll();
        bank = all.firstWhere((a) => a.name == 'Bancolombia');
        cash = all.firstWhere((a) => a.name == 'Efectivo');
      });

      tearDownAll(() => harness.dispose());

      group('crear una deuda', () {
        test('sin cuenta no toca el dinero', () async {
          final before = await balanceOf(bank);
          await create('  Pedro ', amount: '80000', due: DateTime(2026, 12, 1), notes: ' Para el arriendo ');

          final debt = await debtNamed('Pedro');
          expect(debt.direction, DebtDirection.payable);
          expect(debt.amount, 80000);
          expect(debt.paid, 0);
          expect(debt.remaining, 80000);
          expect(debt.currency, 'COP');
          expect(debt.startDate, start);
          expect(debt.dueDate, DateTime(2026, 12, 1));
          expect(debt.notes, 'Para el arriendo');
          expect(debt.isArchived, isFalse);
          expect(await balanceOf(bank), before);
        });

        test('si me prestaron y lo registro, el dinero entra a la cuenta', () async {
          final before = await balanceOf(bank);
          await create('Juan', amount: '500000', account: bank);

          expect(await balanceOf(bank), before + 500000);
          final recent = await transactions.fetchRecent();
          final movement = recent.firstWhere((t) => t.description == 'Préstamo de Juan');
          expect(movement.type, TransactionType.income);
          expect(movement.amount, 500000);
          expect(movement.date, start);
        });

        test('si presté y lo registro, el dinero sale de la cuenta', () async {
          final before = await balanceOf(cash);
          await create('María', direction: DebtDirection.receivable, amount: '30000', account: cash);

          expect(await balanceOf(cash), before - 30000);
          final movement = (await transactions.fetchRecent()).firstWhere(
            (t) => t.description == 'Préstamo a María',
          );
          expect(movement.type, TransactionType.expense);
        });

        test('una cuenta que no existe no deja la deuda a medias', () async {
          final total = (await debts.fetchAll()).length;

          await expectLater(
            debts.create(
              DebtDraft(
                direction: DebtDirection.payable,
                counterparty: 'Fantasma',
                amount: '1000',
                startDate: start,
                accountId: '99999999-9999-9999-9999-999999999999',
              ),
            ),
            failsWith('23503', 'cuenta no existe'),
          );
          expect((await debts.fetchAll()).length, total);
        });

        test('rechaza monto cero, nombre vacío y vencimiento anterior al inicio', () async {
          await expectLater(create('Cero', amount: '0'), failsWith('23514'));
          await expectLater(create('   '), failsWith('23514'));
          await expectLater(
            create('Atrasada', due: DateTime(2026, 9, 1)),
            failsWith('23514'),
          );
        });
      });

      group('abonos', () {
        test('un abono baja lo pendiente y mueve la cuenta', () async {
          await create('Carlos', amount: '300000');
          final debt = await debtNamed('Carlos');
          final before = await balanceOf(bank);

          await debts.registerPayment(
            debtId: debt.id,
            accountId: bank.id,
            amount: '100000.50',
            date: DateTime(2026, 10, 15),
          );

          final updated = await debtNamed('Carlos');
          expect(updated.paid, 100000.5);
          expect(updated.remaining, 199999.5);
          expect(await balanceOf(bank), before - 100000.5); // pagar es un gasto

          final payments = await debts.fetchPayments(debt.id);
          expect(payments, hasLength(1));
          expect(payments.single.amount, 100000.5);
          expect(payments.single.date, DateTime(2026, 10, 15));
          expect(payments.single.accountId, bank.id);
          expect(payments.single.description, 'Abono a Carlos');
        });

        test('cobrar un abono es un ingreso, con descripción propia', () async {
          await create('Lucía', direction: DebtDirection.receivable, amount: '100000');
          final debt = await debtNamed('Lucía');
          final before = await balanceOf(cash);

          await debts.registerPayment(
            debtId: debt.id,
            accountId: cash.id,
            amount: '40000',
            date: DateTime(2026, 10, 16),
            description: 'Cuota 1',
          );

          expect(await balanceOf(cash), before + 40000);
          expect((await debtNamed('Lucía')).remaining, 60000);
          expect((await debts.fetchPayments(debt.id)).single.description, 'Cuota 1');
        });

        test('un abono que se pasa falla con mensaje en español y no deja nada a medias', () async {
          await create('Luis', amount: '200000');
          final debt = await debtNamed('Luis');
          final movements = (await transactions.fetchRecent()).length;
          final balance = await balanceOf(bank);

          await expectLater(
            debts.registerPayment(
              debtId: debt.id,
              accountId: bank.id,
              amount: '200000.01',
              date: DateTime(2026, 10, 15),
            ),
            throwsA(
              isA<PostgrestException>()
                  .having((e) => e.code, 'code', '23514')
                  .having(
                    (e) => debtErrorMessage(l10n, e),
                    'mensaje al usuario',
                    'El abono supera lo que falta por pagar',
                  ),
            ),
          );

          // Atómico: ni movimiento, ni abono, ni cambio de saldo.
          expect((await transactions.fetchRecent()).length, movements);
          expect(await debts.fetchPayments(debt.id), isEmpty);
          expect(await balanceOf(bank), balance);
        });

        test('pagar exactamente lo que falta salda la deuda, y ya no admite más', () async {
          await create('Sofía', amount: '90000');
          final debt = await debtNamed('Sofía');

          await debts.registerPayment(
            debtId: debt.id,
            accountId: bank.id,
            amount: '90000',
            date: DateTime(2026, 10, 20),
          );

          final settled = await debtNamed('Sofía');
          expect(settled.isSettled, isTrue);
          expect(settled.statusOn(DateTime(2026, 10, 21)), DebtStatus.settled);

          await expectLater(
            debts.registerPayment(
              debtId: debt.id,
              accountId: bank.id,
              amount: '1',
              date: DateTime(2026, 10, 21),
            ),
            failsWith('23514', 'supera lo que falta'),
          );
        });

        test('una deuda archivada no admite abonos hasta restaurarla', () async {
          await create('Andrés', amount: '50000');
          final debt = await debtNamed('Andrés');
          await debts.setArchived(debt.id, isArchived: true);
          expect((await debtNamed('Andrés')).isArchived, isTrue);

          await expectLater(
            debts.registerPayment(
              debtId: debt.id,
              accountId: bank.id,
              amount: '1000',
              date: DateTime(2026, 10, 21),
            ),
            failsWith('23514', 'archivada'),
          );

          await debts.setArchived(debt.id, isArchived: false);
          await debts.registerPayment(
            debtId: debt.id,
            accountId: bank.id,
            amount: '1000',
            date: DateTime(2026, 10, 21),
          );
          expect((await debtNamed('Andrés')).paid, 1000);
        });
      });

      group('editar', () {
        test('se pueden cambiar la persona, el monto, el vencimiento y las notas', () async {
          await create('Diego', amount: '100000');
          final debt = await debtNamed('Diego');

          await debts.update(
            debt.id,
            counterparty: 'Diego Ruiz',
            amount: '150000',
            dueDate: DateTime(2027, 1, 15),
            notes: 'Cambió el plan',
          );

          final edited = await debtNamed('Diego Ruiz');
          expect(edited.amount, 150000);
          expect(edited.dueDate, DateTime(2027, 1, 15));
          expect(edited.notes, 'Cambió el plan');

          await debts.update(
            debt.id,
            counterparty: 'Diego Ruiz',
            amount: '150000',
            dueDate: null,
            notes: null,
          );
          final cleared = await debtNamed('Diego Ruiz');
          expect(cleared.dueDate, isNull);
          expect(cleared.notes, isNull);
        });

        test('el monto no puede bajar de lo ya pagado', () async {
          await create('Elena', amount: '100000');
          final debt = await debtNamed('Elena');
          await debts.registerPayment(
            debtId: debt.id,
            accountId: bank.id,
            amount: '60000',
            date: DateTime(2026, 10, 15),
          );

          await expectLater(
            debts.update(debt.id, counterparty: 'Elena', amount: '59999.99'),
            failsWith('23514', 'menor a lo que ya se ha pagado'),
          );
          // Igual a lo pagado sí se puede.
          await debts.update(debt.id, counterparty: 'Elena', amount: '60000');
          expect((await debtNamed('Elena')).isSettled, isTrue);
        });
      });

      group('los abonos son movimientos', () {
        late Debt debt;
        late String transactionId;

        setUpAll(() async {
          await create('Fabián', amount: '400000');
          debt = await debtNamed('Fabián');
          await debts.registerPayment(
            debtId: debt.id,
            accountId: bank.id,
            amount: '150000',
            date: DateTime(2026, 10, 15),
          );
          transactionId = (await debts.fetchPayments(debt.id)).single.transactionId;
        });

        test('corregir el monto del movimiento recalcula la deuda', () async {
          await transactions.update(
            transactionId,
            TransactionDraft(
              type: TransactionType.expense,
              accountId: bank.id,
              amount: '175000',
              date: DateTime(2026, 10, 15),
              description: 'Abono a Fabián',
            ),
          );

          final updated = await debtNamed('Fabián');
          expect(updated.paid, 175000);
          expect(updated.remaining, 225000);
        });

        test('el movimiento de un abono no puede cambiar de tipo', () async {
          await expectLater(
            transactions.update(
              transactionId,
              TransactionDraft(
                type: TransactionType.income,
                accountId: bank.id,
                amount: '175000',
                date: DateTime(2026, 10, 15),
              ),
            ),
            failsWith('23514', 'abono de una deuda'),
          );
        });

        test('eliminar el movimiento elimina el abono y devuelve el dinero', () async {
          final before = await balanceOf(bank);

          // Eliminar un abono es eliminar su movimiento: el enlace se va con él.
          await transactions.delete(transactionId);

          expect(await debts.fetchPayments(debt.id), isEmpty);
          expect((await debtNamed('Fabián')).paid, 0);
          expect(await balanceOf(bank), before + 175000);
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no ve mis deudas ni mis abonos', () async {
          await create('Solo de Ana', amount: '1000');
          final debt = await debtNamed('Solo de Ana');
          final beto = DebtRepository(betoClient);

          expect(await beto.fetchAll(), isEmpty);
          expect(await beto.fetchPayments(debt.id), isEmpty);
        });

        test('otro usuario no puede abonar a mi deuda', () async {
          final debt = await debtNamed('Solo de Ana');

          await expectLater(
            DebtRepository(betoClient).registerPayment(
              debtId: debt.id,
              accountId: bank.id,
              amount: '100',
              date: DateTime(2026, 10, 21),
            ),
            failsWith('23503', 'deuda no existe'),
          );
        });

        test('otro usuario no puede usar mi cuenta al crear una deuda', () async {
          await expectLater(
            DebtRepository(betoClient).create(
              DebtDraft(
                direction: DebtDirection.payable,
                counterparty: 'Intruso',
                amount: '100',
                startDate: start,
                accountId: bank.id,
              ),
            ),
            failsWith('23503', 'cuenta no existe'),
          );
        });

        test('sin sesión no se ve ni se hace nada', () async {
          final anonymous = DebtRepository(harness.newClient());

          await expectLater(anonymous.fetchAll(), throwsA(isA<PostgrestException>()));
          await expectLater(
            anonymous.create(
              DebtDraft(
                direction: DebtDirection.payable,
                counterparty: 'X',
                amount: '1',
                startDate: start,
              ),
            ),
            throwsA(isA<PostgrestException>()),
          );
        });
      });
    },
  );
}
