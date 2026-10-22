import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String categoryErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'Ya tienes una categoría activa con ese nombre.';
      case '23514':
        return 'Revisa los datos: el nombre no puede estar vacío.';
      case 'PGRST301':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';
}
