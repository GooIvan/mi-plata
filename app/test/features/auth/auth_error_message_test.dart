import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/auth/presentation/auth_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  const generic = 'No se pudo completar la operación. Intenta de nuevo.';

  test('traduce los códigos conocidos', () {
    const expected = {
      'invalid_credentials': 'Correo o contraseña incorrectos.',
      'user_already_exists': 'Ya existe una cuenta con ese correo.',
      'email_exists': 'Ya existe una cuenta con ese correo.',
      'email_not_confirmed': 'Confirma tu correo antes de iniciar sesión.',
    };

    expected.forEach((code, message) {
      expect(authErrorMessage(l10n, AuthApiException('x', code: code)), message);
    });
  });

  test('los límites de peticiones piden esperar', () {
    for (final code in ['over_request_rate_limit', 'over_email_send_rate_limit']) {
      expect(
        authErrorMessage(l10n, AuthApiException('x', code: code)),
        startsWith('Demasiados intentos'),
      );
    }
  });

  test('un fallo de red habla de conexión', () {
    expect(
      authErrorMessage(l10n, AuthRetryableFetchException()),
      startsWith('No hay conexión'),
    );
  });

  test('un código desconocido o un error cualquiera da el mensaje genérico', () {
    expect(authErrorMessage(l10n, const AuthApiException('x', code: 'otro')), generic);
    expect(authErrorMessage(l10n, const AuthException('x')), generic);
    expect(authErrorMessage(l10n, StateError('boom')), generic);
  });
}
