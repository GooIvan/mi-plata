import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Las pruebas de integración solo corren con --dart-define=INTEGRATION=true.
const integrationEnabled = bool.fromEnvironment('INTEGRATION');
const integrationSkipReason =
    'Necesita Supabase local: --dart-define=INTEGRATION=true';

/// Clientes de Supabase para probar contra el servidor local.
///
/// Lee SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY de app/.env. Cada usuario de
/// prueba es nuevo; se borran con `supabase db reset`.
class IntegrationHarness {
  IntegrationHarness() : _env = _readEnv();

  final Map<String, String> _env;
  final _clients = <SupabaseClient>[];

  static Map<String, String> _readEnv() {
    final values = <String, String>{};
    for (final line in File('.env').readAsLinesSync()) {
      final separator = line.indexOf('=');
      if (separator > 0 && !line.startsWith('#')) {
        values[line.substring(0, separator)] = line.substring(separator + 1);
      }
    }
    return values;
  }

  /// Un cliente sin sesión. Usa el flujo implícito: el PKCE de la app real
  /// necesita almacenamiento en disco.
  SupabaseClient newClient() {
    final client = SupabaseClient(
      _env['SUPABASE_URL']!,
      _env['SUPABASE_PUBLISHABLE_KEY']!,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    _clients.add(client);
    return client;
  }

  /// Un cliente con un usuario nuevo y la sesión ya abierta. [language] es el
  /// idioma con que se registra (si no se indica, no manda ninguno).
  Future<SupabaseClient> signedUpClient(String prefix, {String? language}) async {
    final client = newClient();
    final email = '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final response = await client.auth.signUp(
      email: email,
      password: 'clave-segura-1',
      data: language == null ? null : {'language': language},
    );
    expect(response.session, isNotNull, reason: 'el registro abre sesión');
    return client;
  }

  Future<void> dispose() async {
    for (final client in _clients) {
      await client.dispose();
    }
  }
}
