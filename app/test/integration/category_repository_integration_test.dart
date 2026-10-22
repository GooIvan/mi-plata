// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/accounts/data/account_repository.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/categories/presentation/category_error_message.dart';
import 'package:mi_plata/features/transactions/data/transaction_repository.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';

void main() {
  group(
    'CategoryRepository contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;
      late SupabaseClient betoClient;
      late CategoryRepository categories;
      late SupabaseClient anaClient;

      Future<Category> named(String name, [CategoryRepository? repository]) async =>
          (await (repository ?? categories).fetchAll()).firstWhere(
            (category) => category.name == name,
          );

      Matcher failsWith(String code) => throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', code),
      );

      setUpAll(() async {
        harness = IntegrationHarness();
        anaClient = await harness.signedUpClient('ana');
        betoClient = await harness.signedUpClient('beto');
        categories = CategoryRepository(anaClient);
      });

      tearDownAll(() => harness.dispose());

      test('cada usuario nuevo recibe 13 categorías por defecto', () async {
        final all = await categories.fetchAll();

        expect(all, hasLength(13));
        expect(all.where((c) => c.type == CategoryType.expense), hasLength(10));
        expect(all.where((c) => c.type == CategoryType.income), hasLength(3));
        expect(all.every((c) => !c.isArchived), isTrue);
      });

      test('crear, renombrar y archivar', () async {
        await categories.create(name: 'Mascotas', type: CategoryType.expense);
        var mascotas = await named('Mascotas');
        expect(mascotas.type, CategoryType.expense);
        expect(mascotas.isArchived, isFalse);

        await categories.rename(mascotas.id, 'Mascotas y veterinario');
        mascotas = await named('Mascotas y veterinario');

        await categories.setArchived(mascotas.id, isArchived: true);
        // Las archivadas siguen en la lista completa, marcadas como tales.
        expect((await named('Mascotas y veterinario')).isArchived, isTrue);

        await categories.setArchived(mascotas.id, isArchived: false);
        expect((await named('Mascotas y veterinario')).isArchived, isFalse);
      });

      test('el nombre no se repite entre activas del mismo tipo', () async {
        await expectLater(
          categories.create(name: 'MERCADO', type: CategoryType.expense),
          throwsA(
            isA<PostgrestException>()
                .having((e) => e.code, 'code', '23505')
                .having(
                  (e) => categoryErrorMessage(e),
                  'mensaje',
                  'Ya tienes una categoría activa con ese nombre.',
                ),
          ),
        );
      });

      test('el mismo nombre se permite en el otro tipo', () async {
        await categories.create(name: 'Otros', type: CategoryType.income);
        await categories.create(name: 'Reembolsos', type: CategoryType.expense);
        await categories.create(name: 'Reembolsos', type: CategoryType.income);

        final all = await categories.fetchAll();
        expect(
          all.where((c) => c.name == 'Reembolsos').map((c) => c.type).toSet(),
          {CategoryType.expense, CategoryType.income},
        );
      });

      test('archivada, su nombre queda libre; restaurar puede chocar', () async {
        await categories.create(name: 'Temporal', type: CategoryType.expense);
        final first = await named('Temporal');
        await categories.setArchived(first.id, isArchived: true);

        // El nombre quedó libre: se puede crear otra igual.
        await categories.create(name: 'Temporal', type: CategoryType.expense);

        // Pero ahora restaurar la vieja choca con la nueva.
        await expectLater(
          categories.setArchived(first.id, isArchived: false),
          failsWith('23505'),
        );
      });

      test('un nombre vacío lo rechaza la base de datos', () async {
        await expectLater(
          categories.create(name: '   ', type: CategoryType.expense),
          failsWith('23514'),
        );
      });

      test('archivar una categoría en uso no afecta a sus movimientos', () async {
        final accounts = AccountRepository(anaClient);
        await accounts.create(
          name: 'Bancolombia',
          type: AccountType.bank,
          initialBalance: '100000',
        );
        final account = (await accounts.fetchAll()).single;
        final transporte = await named('Transporte');

        final transactions = TransactionRepository(anaClient);
        await transactions.create(
          TransactionDraft(
            type: TransactionType.expense,
            accountId: account.id,
            categoryId: transporte.id,
            amount: '8000',
            date: DateTime(2026, 10, 22),
          ),
        );

        await categories.setArchived(transporte.id, isArchived: true);

        final moved = (await transactions.fetchRecent()).single;
        expect(moved.categoryId, transporte.id);
        // El nombre sigue disponible para mostrarlo en la lista.
        expect((await named('Transporte')).isArchived, isTrue);
      });

      test('cada usuario solo ve y modifica sus categorías', () async {
        final beto = CategoryRepository(betoClient);
        await beto.create(name: 'Solo de Beto', type: CategoryType.expense);

        expect(
          (await categories.fetchAll()).where((c) => c.name == 'Solo de Beto'),
          isEmpty,
        );

        // RLS no da error al tocar filas ajenas: simplemente no las encuentra.
        final mercado = await named('Mercado');
        await beto.rename(mercado.id, 'Hackeada');
        await beto.setArchived(mercado.id, isArchived: true);
        final intacta = await named('Mercado');
        expect(intacta.isArchived, isFalse);

        await expectLater(
          CategoryRepository(harness.newClient()).fetchAll(),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
  );
}
