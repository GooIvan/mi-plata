import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String transactionErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; los de nuestros
        // triggers (categoría que no corresponde, monedas distintas) ya
        // vienen en español y se muestran tal cual.
        return error.message.contains('violates check constraint')
            ? 'Revisa los datos del movimiento: el monto, las cuentas y la categoría.'
            : error.message;
      case '23503':
        return 'La cuenta o la categoría ya no existe. Vuelve a abrir el formulario.';
      case 'PGRST301':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';
}
