import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/auth/domain/auth_validators.dart';

void main() {
  group('email', () {
    test('acepta un correo válido, con espacios alrededor', () {
      expect(AuthValidators.email(' ana@correo.com '), isNull);
    });

    test('rechaza vacío, nulo y formatos inválidos', () {
      expect(AuthValidators.email(null), 'Ingresa tu correo');
      expect(AuthValidators.email('   '), 'Ingresa tu correo');
      for (final invalid in ['ana', 'ana@', '@correo.com', 'ana@correo']) {
        expect(AuthValidators.email(invalid), 'El correo no es válido');
      }
    });
  });

  group('contraseña', () {
    test('al iniciar sesión solo se exige que no esté vacía', () {
      expect(AuthValidators.requiredPassword('x'), isNull);
      expect(AuthValidators.requiredPassword(''), 'Ingresa tu contraseña');
      expect(AuthValidators.requiredPassword(null), 'Ingresa tu contraseña');
    });

    test('una contraseña nueva exige el largo mínimo', () {
      expect(AuthValidators.newPassword('1234567'), isNotNull);
      expect(AuthValidators.newPassword('12345678'), isNull);
      expect(AuthValidators.newPassword(''), 'Crea una contraseña');
    });

    test('la confirmación debe coincidir', () {
      expect(AuthValidators.passwordConfirmation('abc', 'abc'), isNull);
      expect(
        AuthValidators.passwordConfirmation('abc', 'abd'),
        'Las contraseñas no coinciden',
      );
      expect(
        AuthValidators.passwordConfirmation('', 'abc'),
        'Repite tu contraseña',
      );
    });
  });
}
