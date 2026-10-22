import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error de autenticación a un mensaje para el usuario.
String authErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) {
    return 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Correo o contraseña incorrectos.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak_password':
        return 'La contraseña es muy débil. Usa una más larga o más variada.';
      case 'email_not_confirmed':
        return 'Confirma tu correo antes de iniciar sesión.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
      case 'signup_disabled':
        return 'El registro de usuarios está deshabilitado.';
    }
  }
  return 'No se pudo completar la operación. Intenta de nuevo.';
}
