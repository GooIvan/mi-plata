import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/format/formats.dart';
import 'package:mi_plata/features/accounts/domain/account.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/domain/account_validators.dart';
import 'package:mi_plata/features/accounts/presentation/account_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

String normalized(String text) => text.replaceAll(' ', ' ');

late AppLocalizations l10n;
late Formats formats;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    formats = Formats(l10n);
    await initDates();
  });

  group('Account.fromJson', () {
    test('lee una fila de v_account_balances', () {
      final account = Account.fromJson({
        'id': 'abc',
        'user_id': 'u1',
        'name': 'Bancolombia',
        'type': 'bank',
        'currency': 'COP',
        'is_archived': false,
        'initial_balance': 1000000.00,
        'current_balance': 1180000,
      });

      expect(account.id, 'abc');
      expect(account.name, 'Bancolombia');
      expect(account.type, AccountType.bank);
      expect(account.initialBalance, 1000000);
      expect(account.currentBalance, 1180000);
      expect(account.isArchived, isFalse);
    });

    test('conoce los cuatro tipos de cuenta', () {
      for (final type in ['cash', 'bank', 'wallet', 'card']) {
        expect(AccountType.fromDb(type).dbValue, type);
      }
      expect(() => AccountType.fromDb('otro'), throwsStateError);
    });
  });

  group('validadores', () {
    test('el nombre es obligatorio y tiene un máximo', () {
      expect(AccountValidators.name(l10n, 'Nequi'), isNull);
      expect(AccountValidators.name(l10n, '  '), 'Ponle un nombre a la cuenta');
      expect(AccountValidators.name(l10n, null), 'Ponle un nombre a la cuenta');
      expect(AccountValidators.name(l10n, 'x' * 41), 'Usa 40 caracteres o menos');
      expect(AccountValidators.name(l10n, 'x' * 40), isNull);
    });

    test('el saldo inicial acepta vacío y rechaza basura', () {
      expect(AccountValidators.initialBalance(l10n, ''), isNull);
      expect(AccountValidators.initialBalance(l10n, '1.500.000'), isNull);
      expect(AccountValidators.initialBalance(l10n, 'mucho'), isNotNull);
    });
  });

  group('formatMoney', () {
    test('usa punto para miles y omite los decimales si no los hay', () {
      expect(normalized(formats.money(1500000)), r'$1.500.000');
      expect(normalized(formats.money(0)), r'$0');
      expect(normalized(formats.money(25000)), r'$25.000');
    });

    test('muestra los centavos con coma cuando existen', () {
      expect(normalized(formats.money(1250000.5)), r'$1.250.000,50');
    });

    test('los negativos llevan signo menos', () {
      expect(normalized(formats.money(-350000)), r'-$350.000');
    });
  });

  group('accountErrorMessage', () {
    String message(String? code) =>
        accountErrorMessage(l10n, PostgrestException(message: 'x', code: code));

    test('traduce los códigos de la base de datos', () {
      expect(message('23505'), 'Ya tienes una cuenta activa con ese nombre.');
      expect(message('22003'), 'El monto es demasiado grande.');
      expect(message('PGRST301'), startsWith('Tu sesión expiró'));
    });

    test('lo desconocido da el mensaje genérico', () {
      const generic =
          'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';
      expect(message('XX000'), generic);
      expect(message(null), generic);
      expect(accountErrorMessage(l10n, StateError('boom')), generic);
    });
  });
}
