// Prueba contra un Supabase local de verdad. No corre por defecto:
//
//   supabase start
//   flutter test test/integration --dart-define=INTEGRATION=true
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/categories/data/category_repository.dart';
import 'package:mi_plata/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/integration_harness.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(initDates);

  group(
    'Perfil contra Supabase local',
    skip: integrationEnabled ? false : integrationSkipReason,
    () {
      late IntegrationHarness harness;

      setUpAll(() => harness = IntegrationHarness());
      tearDownAll(() => harness.dispose());

      test(
        'el perfil nace con la cuenta, con los datos del registro',
        () async {
          final client = await harness.signedUpClient(
            'perfil-completo',
            language: 'es',
            metadata: {
              'first_name': '  Ana María ',
              'last_name': 'Pérez Gómez',
              'birth_date': '1990-05-17',
              'profession': 'Diseñadora',
              'monthly_income': '2500000',
              'monthly_income_currency': 'COP',
            },
          );

          final profile = await ProfileRepository(client).fetch();

          expect(profile, isNotNull);
          expect(profile!.firstName, 'Ana María'); // recortado
          expect(profile.lastName, 'Pérez Gómez');
          expect(profile.birthDate, DateTime(1990, 5, 17));
          expect(profile.profession, 'Diseñadora');
          expect(double.parse(profile.monthlyIncome!), 2500000);
          expect(profile.monthlyIncomeCurrency, 'COP');
        },
      );

      test(
        'sin datos opcionales, quedan vacíos; y las categorías siguen naciendo',
        () async {
          final client = await harness.signedUpClient(
            'perfil-minimo',
            language: 'en',
            metadata: {
              'first_name': 'Ana',
              'last_name': 'Pérez',
              'profession': '   ',
            },
          );

          final profile = (await ProfileRepository(client).fetch())!;

          expect(profile.firstName, 'Ana');
          expect(profile.birthDate, isNull);
          expect(profile.profession, isNull);
          expect(profile.monthlyIncome, isNull);
          expect(profile.monthlyIncomeCurrency, isNull);
          // Lo de siempre sigue funcionando: 13 categorías, en inglés.
          final categories = await CategoryRepository(client).fetchAll();
          expect(categories, hasLength(13));
          expect(categories.map((c) => c.name), contains('Groceries'));
        },
      );

      test('un ingreso sin moneda usa pesos', () async {
        final client = await harness.signedUpClient(
          'perfil-moneda',
          metadata: {'monthly_income': '100.5'},
        );
        final profile = (await ProfileRepository(client).fetch())!;
        expect(profile.monthlyIncomeCurrency, 'COP');
        expect(double.parse(profile.monthlyIncome!), 100.5);
      });

      test('cada usuario solo ve su perfil', () async {
        final ana = await harness.signedUpClient(
          'perfil-ana',
          metadata: {'first_name': 'Ana', 'last_name': 'A'},
        );
        final beto = await harness.signedUpClient(
          'perfil-beto',
          metadata: {'first_name': 'Beto', 'last_name': 'B'},
        );

        final rowsOfAna = await ana.from('profiles').select();
        final rowsOfBeto = await beto.from('profiles').select();

        expect(rowsOfAna, hasLength(1));
        expect(rowsOfAna.single['first_name'], 'Ana');
        expect(rowsOfBeto.single['first_name'], 'Beto');
        // Ni cambiando el de otro.
        final changed = await beto
            .from('profiles')
            .update({'first_name': 'Hackeado'})
            .eq('user_id', rowsOfAna.single['user_id'] as String)
            .select();
        expect(changed, isEmpty);
        expect((await ProfileRepository(ana).fetch())!.firstName, 'Ana');
      });

      test('sin sesión no se lee ningún perfil', () async {
        await expectLater(
          ProfileRepository(harness.newClient()).fetch(),
          throwsA(isA<PostgrestException>()),
        );
      });

      group('lo inválido se rechaza y no deja una cuenta a medias', () {
        Future<void> rejected(
          String prefix,
          Map<String, Object?> metadata,
        ) async {
          final client = harness.newClient();
          await expectLater(
            harness.signUp(client, prefix, metadata: metadata),
            throwsA(isA<AuthException>()),
          );
          // No hay sesión: la cuenta no se creó.
          expect(client.auth.currentSession, isNull);
        }

        test('una fecha de nacimiento futura', () async {
          await rejected('perfil-futuro', {
            'first_name': 'Ana',
            'birth_date': '2999-01-01',
          });
        });

        test('una fecha anterior a 1900', () async {
          await rejected('perfil-antiguo', {
            'first_name': 'Ana',
            'birth_date': '1850-01-01',
          });
        });

        test('un ingreso en cero o negativo', () async {
          await rejected('perfil-cero', {'monthly_income': '0'});
          await rejected('perfil-negativo', {'monthly_income': '-5'});
        });

        test('un nombre de más de 60 caracteres', () async {
          await rejected('perfil-largo', {'first_name': 'x' * 61});
        });

        test('una fecha que no es fecha', () async {
          await rejected('perfil-basura', {'birth_date': 'ayer'});
        });
      });
    },
  );
}
