import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String debtErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; los de nuestros
        // triggers y funciones ("El abono supera lo que falta por pagar")
        // ya vienen en español y se muestran tal cual.
        return error.message.contains('violates check constraint')
            ? 'Revisa los datos de la deuda: el monto y las fechas.'
            : error.message;
      case '23503':
        return 'La cuenta o la deuda ya no existe. Vuelve a abrir la pantalla.';
      case 'PGRST301':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';
}
