// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
//
// Lee SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY de app/.env. Cada ejecución crea
// usuarios de prueba nuevos; se borran con `supabase db reset`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/account_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('INTEGRATION');

Map<String, String> _readEnv() {
  final values = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final separator = line.indexOf('=');
    if (separator > 0 && !line.startsWith('#')) {
      values[line.substring(0, separator)] = line.substring(separator + 1);
    }
  }
  return values;
}

void main() {
  group(
    'AccountRepository contra Supabase local',
    skip: _enabled
        ? false
        : 'Necesita Supabase local: --dart-define=INTEGRATION=true',
    () {
      late Map<String, String> env;
      late SupabaseClient ana;
      late SupabaseClient beto;
      late AccountRepository repository;
      final clients = <SupabaseClient>[];

      // Flujo implícito: el PKCE de la app real necesita almacenamiento en disco.
      SupabaseClient newClient() {
        final client = SupabaseClient(
          env['SUPABASE_URL']!,
          env['SUPABASE_PUBLISHABLE_KEY']!,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        clients.add(client);
        return client;
      }

      Future<SupabaseClient> signedUpClient(String prefix) async {
        final client = newClient();
        final email = '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com';
        final response = await client.auth.signUp(
          email: email,
          password: 'clave-segura-1',
        );
        expect(response.session, isNotNull, reason: 'el registro abre sesión');
        return client;
      }

      setUpAll(() async {
        env = _readEnv();
        ana = await signedUpClient('ana');
        beto = await signedUpClient('beto');
        repository = AccountRepository(ana);
      });

      tearDownAll(() async {
        for (final client in clients) {
          await client.dispose();
        }
      });

      test('crear, listar, editar y archivar', () async {
        expect(await repository.fetchAll(), isEmpty);

        await repository.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '1500000.50',
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
          initialBalance: '0',
        );

        await expectLater(
          repository.create(
            name: 'DUPLICADA',
            type: AccountType.cash,
            initialBalance: '0',
          ),
          throwsA(
            isA<PostgrestException>()
                .having((e) => e.code, 'code', '23505')
                .having(
                  (e) => accountErrorMessage(e),
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
          initialBalance: '0',
        );
      });

      test('la base de datos rechaza datos inválidos', () async {
        await expectLater(
          repository.create(
            name: '   ',
            type: AccountType.cash,
            initialBalance: '0',
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
          ),
        );

        await expectLater(
          repository.create(
            name: 'Enorme',
            type: AccountType.cash,
            initialBalance: '1000000000000',
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
          initialBalance: '-350000.25',
        );

        final visa = (await repository.fetchAll()).firstWhere(
          (account) => account.name == 'Visa',
        );
        expect(visa.currentBalance, -350000.25);
      });

      test('cada usuario solo ve sus cuentas', () async {
        await repository.create(
          name: 'Solo de Ana',
          type: AccountType.bank,
          initialBalance: '1',
        );

        final deBeto = await AccountRepository(beto).fetchAll();
        expect(deBeto, isEmpty);

        await expectLater(
          AccountRepository(newClient()).fetchAll(),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
