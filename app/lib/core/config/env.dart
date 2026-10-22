import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Acceso tipado a las variables definidas en `app/.env`.
class Env {
  const Env._();

  static String get supabaseUrl => dotenv.get('SUPABASE_URL');
  static String get supabasePublishableKey =>
      dotenv.get('SUPABASE_PUBLISHABLE_KEY');
}
