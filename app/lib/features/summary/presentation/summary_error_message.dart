import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce un error al cargar el resumen a un mensaje para el usuario.
String summaryErrorMessage(Object error) {
  if (error is PostgrestException && error.code == 'PGRST301') {
    return 'Tu sesión expiró. Vuelve a iniciar sesión.';
  }
  return 'No se pudo cargar el resumen. Revisa tu conexión e intenta de nuevo.';
}
