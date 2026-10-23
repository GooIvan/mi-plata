import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String budgetErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; el de nuestro trigger
        // ("Solo las categorías de gasto pueden tener presupuesto") ya viene en
        // español y se muestra tal cual.
        return error.message.contains('violates check constraint')
            ? 'Revisa el monto del presupuesto.'
            : error.message;
      case '23503':
        return 'La categoría ya no existe. Vuelve a abrir la pantalla.';
      case 'PGRST301':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión e intenta de nuevo.';
}
