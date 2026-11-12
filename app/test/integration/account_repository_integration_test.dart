// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/account_error_message.dart';
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
    'AccountRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient beto;
      late AccountRepository repository;

      setUpAll(() async {
        harness = IntegrationHarness();
        repository = AccountRepository(await harness.signedUpClient('ana'));
        beto = await harness.signedUpClient('beto');
      });

      tearDownAll(() => harness.dispose());

      test('crear, listar, editar y archivar', () async {
        expect(await repository.fetchAll(), isEmpty);

        await repository.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '1500000.50', currency: 'COP',
        );
        var accounts = await repository.fetchAll();
        expect(accounts, hasLength(1));
        expect(accounts.single.name, 'Bancolombia');
        expect(accounts.single.type, AccountType.bank);
        expect(accounts.single.currency, 'COP');
        expect(accounts.single.initialBalance, 1500000.5);
        expect(accounts.single.currentBalance, 1500000.5);
        expect(accounts.single.isArchived, isFalse);

        final id = accounts.single.id;
        await repository.update(
          id: id,
          name: 'Bancolombia nómina',
          type: AccountType.wallet,
          initialBalance: '2000000',
        );
        accounts = await repository.fetchAll();
        expect(accounts.single.name, 'Bancolombia nómina');
        expect(accounts.single.type, AccountType.wallet);
        expect(accounts.single.currentBalance, 2000000);

        await repository.setArchived(id, isArchived: true);
        expect((await repository.fetchAll()).single.isArchived, isTrue);

        await repository.setArchived(id, isArchived: false);
        expect((await repository.fetchAll()).single.isArchived, isFalse);
      });

      test('el nombre no se repite entre cuentas activas', () async {
        await repository.create(
          name: 'Duplicada',
          type: AccountType.cash,
          initialBalance: '0', currency: 'COP',
        );

        await expectLater(
          repository.create(
            name: 'DUPLICADA',
            type: AccountType.cash,
            initialBalance: '0', currency: 'COP',
          ),
          throwsA(
            isA<PostgrestException>()
                .having((e) => e.code, 'code', '23505')
                .having(
                  (e) => accountErrorMessage(l10n, e),
                  'mensaje',
                  'Ya tienes una cuenta activa con ese nombre.',
                ),
          ),
        );

        // Archivada, su nombre queda libre.
        final original = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Duplicada',
        );
        await repository.setArchived(original.id, isArchived: true);
        await repository.create(
          name: 'Duplicada',
          type: AccountType.cash,
          initialBalance: '0', currency: 'COP',
        );
      });

      test('la base de datos rechaza datos inválidos', () async {
        await expectLater(
          repository.create(
            name: '   ',
            type: AccountType.cash,
            initialBalance: '0', currency: 'COP',
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
          ),
        );

        await expectLater(
          repository.create(
            name: 'Enorme',
            type: AccountType.cash,
            initialBalance: '1000000000000', currency: 'COP',
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '22003'),
          ),
        );
      });

      test('un saldo negativo (deuda de tarjeta) se guarda y se lee', () async {
        await repository.create(
          name: 'Visa',
          type: AccountType.card,
          initialBalance: '-350000.25', currency: 'COP',
        );

        final visa = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Visa',
        );
        expect(visa.currentBalance, -350000.25);
      });

      test('una tarjeta guarda su cupo y sus días, y se pueden cambiar', () async {
        await repository.create(
          name: 'Visa Gold',
          type: AccountType.card,
          initialBalance: '0',
          currency: 'COP',
          creditLimit: '3000000',
          statementDay: 15,
          paymentDay: 30,
        );

        var card = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Visa Gold',
        );
        expect(card.creditLimit, 3000000);
        expect(card.statementDay, 15);
        expect(card.paymentDay, 30);
        expect(card.cardCalendar, isNotNull);

        // Quitar el cupo y cambiar los días: update envía siempre los tres.
        await repository.update(
          id: card.id,
          name: 'Visa Gold',
          type: AccountType.card,
          initialBalance: '0',
          statementDay: 5,
          paymentDay: 20,
        );
        card = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Visa Gold',
        );
        expect(card.creditLimit, isNull);
        expect(card.statementDay, 5);
        expect(card.paymentDay, 20);
      });

      test('solo una tarjeta puede tener cupo y días', () async {
        await expectLater(
          repository.create(
            name: 'Banco con cupo',
            type: AccountType.bank,
            initialBalance: '0',
            currency: 'COP',
            creditLimit: '1000000',
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
          ),
        );

        // Pasar una tarjeta a otro tipo sin borrar sus datos tampoco vale.
        await repository.create(
          name: 'Tarjeta que cambia',
          type: AccountType.card,
          initialBalance: '0',
          currency: 'COP',
          creditLimit: '1000000',
          statementDay: 10,
          paymentDay: 25,
        );
        final card = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Tarjeta que cambia',
        );
        await expectLater(
          repository.update(
            id: card.id,
            name: 'Tarjeta que cambia',
            type: AccountType.bank,
            initialBalance: '0',
            creditLimit: '1000000',
            statementDay: 10,
            paymentDay: 25,
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
          ),
        );
        // Sin los datos de la tarjeta, sí.
        await repository.update(
          id: card.id,
          name: 'Tarjeta que cambia',
          type: AccountType.bank,
          initialBalance: '0',
        );
      });

      test('los días van juntos y dentro del mes; el cupo, mayor que cero', () async {
        Future<void> create({
          String? limit,
          int? statementDay,
          int? paymentDay,
        }) => repository.create(
          name: 'Visa inválida',
          type: AccountType.card,
          initialBalance: '0',
          currency: 'COP',
          creditLimit: limit,
          statementDay: statementDay,
          paymentDay: paymentDay,
        );

        for (final invalid in [
          () => create(statementDay: 15),
          () => create(paymentDay: 30),
          () => create(statementDay: 0, paymentDay: 10),
          () => create(statementDay: 10, paymentDay: 32),
          () => create(limit: '0'),
          () => create(limit: '-5'),
        ]) {
          await expectLater(
            invalid(),
            throwsA(
              isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
            ),
          );
        }
      });

      test('cada usuario solo ve sus cuentas', () async {
        await repository.create(
          name: 'Solo de Ana',
          type: AccountType.bank,
          initialBalance: '1', currency: 'COP',
        );

        expect(await AccountRepository(beto).fetchAll(), isEmpty);
        await expectLater(
          AccountRepository(harness.newClient()).fetchAll(),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
