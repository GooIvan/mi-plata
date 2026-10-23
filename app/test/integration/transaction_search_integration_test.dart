// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_filter.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';

void main() {
  group(
    'Búsqueda y paginación contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient ana;
      late TransactionRepository repository;
      late String bank;
      late String cash;
      late Map<String, String> category;

      const empty = TransactionFilter.empty;

      Future<List<Transaction>> all(TransactionFilter filter) async {
        final result = <Transaction>[];
        for (var offset = 0;; offset += TransactionRepository.pageSize) {
          final page = await repository.fetchPage(filter: filter, offset: offset);
          result.addAll(page);
          if (page.length < TransactionRepository.pageSize) return result;
        }
      }

      List<String?> descriptions(List<Transaction> list) =>
          list.map((t) => t.description).toList();

      setUpAll(() async {
        harness = IntegrationHarness();
        ana = await harness.signedUpClient('ana');
        repository = TransactionRepository(ana);

        final accounts = AccountRepository(ana);
        await accounts.create(name: 'Bancolombia', type: AccountType.bank, initialBalance: '0', currency: 'COP');
        await accounts.create(name: 'Efectivo', type: AccountType.cash, initialBalance: '0', currency: 'COP');
        final list = await accounts.fetchAll();
        bank = list.firstWhere((a) => a.name == 'Bancolombia').id;
        cash = list.firstWhere((a) => a.name == 'Efectivo').id;
        category = {
          for (final c in await CategoryRepository(ana).fetchAll()) c.name: c.id,
        };

        Map<String, dynamic> row(
          String description,
          String amount,
          String date, {
          String type = 'expense',
          String? account,
          String? destination,
          String? categoryName,
        }) => {
          'type': type,
          'account_id': account ?? bank,
          'destination_account_id': destination,
          'category_id': categoryName == null ? null : category[categoryName],
          'amount': amount,
          'transaction_date': date,
          'description': description,
        };

        await ana.from('transactions').insert([
          // 95 de un mismo día, todos con el mismo created_at (un solo INSERT):
          // el orden entre ellos depende solo del desempate por id.
          for (var i = 0; i < 95; i++) row('Masivo $i', '100', '2026-02-10'),
          row('Mercado Éxito', '120000', '2026-03-05', categoryName: 'Mercado'),
          row('RAPPI hamburguesa', '35000', '2026-03-06', categoryName: 'Alimentación'),
          row('Rappi sin categoría', '18000', '2026-03-31'),
          row('Descuento 50% ropa', '90000', '2026-04-01', categoryName: 'Ropa'),
          row('Cuota 50 de 100', '20000', '2026-04-02'),
          row('Archivo_final', '5000', '2026-04-03'),
          row('Archivo-final', '6000', '2026-04-04'),
          row('Sueldo', '3000000', '2026-04-05', type: 'income', categoryName: 'Salario'),
          row('Paso al efectivo', '200000', '2026-04-06', type: 'transfer', destination: cash),
          row('Almuerzo en efectivo', '25000', '2026-04-07', account: cash, categoryName: 'Alimentación'),
        ]);
      });

      tearDownAll(() => harness.dispose());

      group('paginación', () {
        test('las páginas no repiten ni se saltan movimientos de una misma fecha', () async {
          final first = await repository.fetchPage(filter: empty, offset: 0);
          final second = await repository.fetchPage(filter: empty, offset: 40);
          final third = await repository.fetchPage(filter: empty, offset: 80);

          // 105 en total: 40 + 40 + 25.
          expect(first, hasLength(40));
          expect(second, hasLength(40));
          expect(third, hasLength(25));

          final ids = [...first, ...second, ...third].map((t) => t.id).toList();
          expect(ids, hasLength(105));
          expect(ids.toSet(), hasLength(105), reason: 'ningún repetido');
        });

        test('recorriendo todas las páginas salen todos, una vez cada uno', () async {
          final result = await all(empty);
          // 95 masivos + 10 con nombre.
          expect(result, hasLength(105));
          expect(result.map((t) => t.id).toSet(), hasLength(105));
        });

        test('la última página llega incompleta, y una posterior, vacía', () async {
          expect(await repository.fetchPage(filter: empty, offset: 80), hasLength(25));
          expect(await repository.fetchPage(filter: empty, offset: 120), isEmpty);
        });

        test('van del más reciente al más antiguo', () async {
          final result = await all(empty);
          final dates = result.map((t) => t.date).toList();

          expect([...dates]..sort((a, b) => b.compareTo(a)), dates);
          expect(result.first.description, 'Almuerzo en efectivo');
        });

        test('repetir la misma consulta da el mismo orden', () async {
          final once = (await repository.fetchPage(filter: empty, offset: 0)).map((t) => t.id);
          final twice = (await repository.fetchPage(filter: empty, offset: 0)).map((t) => t.id);

          expect(once.toList(), twice.toList());
        });
      });

      group('texto', () {
        test('sin importar mayúsculas', () async {
          final result = await all(empty.withText('rappi'));

          expect(descriptions(result), ['Rappi sin categoría', 'RAPPI hamburguesa']);
        });

        test('busca en cualquier parte de la descripción', () async {
          expect(descriptions(await all(empty.withText('hambur'))), ['RAPPI hamburguesa']);
        });

        test('un % se busca tal cual y no como comodín', () async {
          final result = await all(empty.withText('50%'));

          expect(descriptions(result), ['Descuento 50% ropa']);
        });

        test('un _ se busca tal cual y no como "cualquier letra"', () async {
          // Con _ de comodín, "Archivo_final" también encontraría "Archivo-final".
          final result = await all(empty.withText('Archivo_final'));

          expect(descriptions(result), ['Archivo_final']);
        });

        test('una barra invertida no rompe la búsqueda', () async {
          expect(await all(empty.withText(r'a\b')), isEmpty);
        });

        test('sin coincidencias, vacío', () async {
          expect(await all(empty.withText('zzz')), isEmpty);
        });
      });

      group('criterios', () {
        test('por tipo', () async {
          final income = await all(empty.withType(TransactionType.income));
          final transfers = await all(empty.withType(TransactionType.transfer));

          expect(descriptions(income), ['Sueldo']);
          expect(descriptions(transfers), ['Paso al efectivo']);
        });

        test('por cuenta: lo que sale y lo que entra', () async {
          final result = await all(empty.withAccount(cash));

          expect(
            descriptions(result),
            ['Almuerzo en efectivo', 'Paso al efectivo'],
          );
        });

        test('por categoría', () async {
          final result = await all(empty.withCategory(category['Alimentación']));

          expect(
            descriptions(result),
            ['Almuerzo en efectivo', 'RAPPI hamburguesa'],
          );
        });

        test('solo los que no tienen categoría', () async {
          final result = await all(empty.withUncategorized().withText('Rappi'));

          expect(descriptions(result), ['Rappi sin categoría']);
        });

        test('el rango de fechas incluye los dos extremos', () async {
          final result = await all(
            empty.withRange(DateTime(2026, 3, 31), DateTime(2026, 4, 2)),
          );

          expect(
            descriptions(result),
            ['Cuota 50 de 100', 'Descuento 50% ropa', 'Rappi sin categoría'],
          );
        });

        test('un rango con un solo extremo', () async {
          final since = await all(empty.withRange(DateTime(2026, 4, 5), null));
          final until = await all(empty.withRange(null, DateTime(2026, 3, 5)));

          expect(
            descriptions(since),
            ['Almuerzo en efectivo', 'Paso al efectivo', 'Sueldo'],
          );
          // Los 95 de febrero y el del 5 de marzo.
          expect(until, hasLength(96));
        });

        test('varios criterios se combinan con "y"', () async {
          final result = await all(
            empty
                .withType(TransactionType.expense)
                .withRange(DateTime(2026, 3, 1), DateTime(2026, 3, 31))
                .withText('rappi'),
          );

          expect(descriptions(result), ['Rappi sin categoría', 'RAPPI hamburguesa']);
        });
      });

      group('aislamiento entre usuarios', () {
        test('otro usuario no encuentra nada, con ningún filtro', () async {
          final beto = TransactionRepository(await harness.signedUpClient('beto'));

          expect(await beto.fetchPage(filter: empty, offset: 0), isEmpty);
          expect(await beto.fetchPage(filter: empty.withText('rappi'), offset: 0), isEmpty);
          expect(await beto.fetchPage(filter: empty.withAccount(bank), offset: 0), isEmpty);
        });

        test('sin sesión falla', () async {
          await expectLater(
            TransactionRepository(harness.newClient()).fetchPage(filter: empty, offset: 0),
            throwsA(isA<PostgrestException>()),
          );
        });
      });
    },
  );
}
