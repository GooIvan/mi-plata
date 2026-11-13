import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/profile/domain/profile_data.dart';
import 'package:mi_plata/features/profile/domain/profile_validators.dart';
import 'package:mi_plata/l10n/l10n.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group('nombres', () {
    test('son obligatorios', () {
      expect(ProfileValidators.firstName(l10n, ''), 'Escribe tus nombres');
      expect(ProfileValidators.firstName(l10n, '   '), 'Escribe tus nombres');
      expect(ProfileValidators.firstName(l10n, null), 'Escribe tus nombres');
      expect(ProfileValidators.lastName(l10n, ''), 'Escribe tus apellidos');
      expect(ProfileValidators.lastName(l10n, null), 'Escribe tus apellidos');
    });

    test('aceptan tildes, ñ, espacios y guiones', () {
      expect(ProfileValidators.firstName(l10n, 'José Ángel'), isNull);
      expect(ProfileValidators.lastName(l10n, 'Muñoz-Peña de la Rosa'), isNull);
    });

    test('tienen un máximo de 60 caracteres', () {
      expect(ProfileValidators.firstName(l10n, 'x' * 60), isNull);
      expect(ProfileValidators.firstName(l10n, 'x' * 61), isNotNull);
      expect(ProfileValidators.lastName(l10n, 'x' * 61), isNotNull);
    });
  });

  group('fecha de nacimiento', () {
    final today = DateTime(2026, 11, 13);

    test('puede faltar', () {
      expect(ProfileValidators.birthDate(l10n, null, today: today), isNull);
    });

    test('hoy y cualquier día pasado valen', () {
      expect(
        ProfileValidators.birthDate(l10n, DateTime(2026, 11, 13), today: today),
        isNull,
      );
      expect(
        ProfileValidators.birthDate(l10n, DateTime(1990, 5, 17), today: today),
        isNull,
      );
      expect(
        ProfileValidators.birthDate(l10n, DateTime(1900), today: today),
        isNull,
      );
    });

    test('una fecha futura no vale', () {
      expect(
        ProfileValidators.birthDate(l10n, DateTime(2026, 11, 14), today: today),
        'Elige una fecha que ya pasó',
      );
    });

    test('una anterior a 1900 no vale', () {
      expect(
        ProfileValidators.birthDate(l10n, DateTime(1899, 12, 31), today: today),
        isNotNull,
      );
    });

    test('la hora del día no cuenta', () {
      expect(
        ProfileValidators.birthDate(
          l10n,
          DateTime(2026, 11, 13, 23, 59),
          today: DateTime(2026, 11, 13, 8),
        ),
        isNull,
      );
    });
  });

  group('profesión e ingreso', () {
    test('la profesión puede ir vacía, y si no, hasta 80 caracteres', () {
      expect(ProfileValidators.profession(l10n, ''), isNull);
      expect(ProfileValidators.profession(l10n, null), isNull);
      expect(
        ProfileValidators.profession(l10n, 'Ingeniera de sistemas'),
        isNull,
      );
      expect(ProfileValidators.profession(l10n, 'x' * 80), isNull);
      expect(ProfileValidators.profession(l10n, 'x' * 81), isNotNull);
    });

    test('el ingreso puede ir vacío; si se escribe, mayor que cero', () {
      expect(ProfileValidators.monthlyIncome(l10n, ''), isNull);
      expect(ProfileValidators.monthlyIncome(l10n, null), isNull);
      expect(ProfileValidators.monthlyIncome(l10n, '2.500.000'), isNull);
      expect(ProfileValidators.monthlyIncome(l10n, '1.234,50'), isNull);
      expect(
        ProfileValidators.monthlyIncome(l10n, '0'),
        'Escribe un monto mayor que cero',
      );
      expect(ProfileValidators.monthlyIncome(l10n, '-5'), isNotNull);
      expect(ProfileValidators.monthlyIncome(l10n, 'mucho'), isNotNull);
    });
  });

  group('ProfileData', () {
    test(
      'arma los metadatos del registro, recortados y solo con lo que se dio',
      () {
        final metadata = ProfileData(
          firstName: '  Ana María ',
          lastName: 'Pérez',
          birthDate: DateTime(1990, 5, 7),
          profession: ' Diseñadora ',
          monthlyIncome: '2500000',
          monthlyIncomeCurrency: 'COP',
        ).toSignUpMetadata();

        expect(metadata, {
          'first_name': 'Ana María',
          'last_name': 'Pérez',
          'birth_date': '1990-05-07',
          'profession': 'Diseñadora',
          'monthly_income': '2500000',
          'monthly_income_currency': 'COP',
        });
      },
    );

    test('lo que no se dio no viaja', () {
      final metadata = const ProfileData(
        firstName: 'Ana',
        lastName: 'Pérez',
        profession: '   ',
      ).toSignUpMetadata();
      expect(metadata, {'first_name': 'Ana', 'last_name': 'Pérez'});
    });

    test('un ingreso sin moneda usa pesos', () {
      final metadata = const ProfileData(monthlyIncome: '100')
          .toSignUpMetadata();
      expect(metadata['monthly_income_currency'], 'COP');
    });

    test('lee una fila de profiles', () {
      final profile = ProfileData.fromJson({
        'user_id': 'u1',
        'first_name': 'Ana',
        'last_name': 'Pérez',
        'birth_date': '1990-05-17',
        'profession': null,
        'monthly_income': 2500000.00,
        'monthly_income_currency': 'COP',
      });

      expect(profile.firstName, 'Ana');
      expect(profile.birthDate, DateTime(1990, 5, 17));
      expect(profile.profession, isNull);
      expect(profile.monthlyIncome, '2500000.0');
      expect(profile.monthlyIncomeCurrency, 'COP');
    });
  });
}
