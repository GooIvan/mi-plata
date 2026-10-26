import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/auth/domain/auth_validators.dart';
import 'package:mi_plata/l10n/l10n.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group('email', () {
    test('acepta un correo válido, con espacios alrededor', () {
      expect(AuthValidators.email(l10n, ' ana@correo.com '), isNull);
    });

    test('rechaza vacío, nulo y formatos inválidos', () {
      expect(AuthValidators.email(l10n, null), 'Ingresa tu correo');
      expect(AuthValidators.email(l10n, '   '), 'Ingresa tu correo');
      for (final invalid in ['ana', 'ana@', '@correo.com', 'ana@correo']) {
        expect(AuthValidators.email(l10n, invalid), 'El correo no es válido');
      }
    });
  });

  group('contraseña', () {
    test('al iniciar sesión solo se exige que no esté vacía', () {
      expect(AuthValidators.requiredPassword(l10n, 'x'), isNull);
      expect(AuthValidators.requiredPassword(l10n, ''), 'Ingresa tu contraseña');
      expect(AuthValidators.requiredPassword(l10n, null), 'Ingresa tu contraseña');
    });

    test('una contraseña nueva exige el largo mínimo', () {
      expect(AuthValidators.newPassword(l10n, '1234567'), isNotNull);
      expect(AuthValidators.newPassword(l10n, '12345678'), isNull);
      expect(AuthValidators.newPassword(l10n, ''), 'Crea una contraseña');
    });

    test('la confirmación debe coincidir', () {
      expect(AuthValidators.passwordConfirmation(l10n, 'abc', 'abc'), isNull);
      expect(
        AuthValidators.passwordConfirmation(l10n, 'abc', 'abd'),
        'Las contraseñas no coinciden',
      );
      expect(
        AuthValidators.passwordConfirmation(l10n, '', 'abc'),
        'Repite tu contraseña',
      );
    });
  });
}
