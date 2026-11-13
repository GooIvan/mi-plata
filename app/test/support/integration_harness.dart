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
/// prueba es nuevo y se borra (con todo lo suyo) al terminar, en [dispose]; si
/// una corrida se interrumpe, `scripts/limpiar-usuarios-de-prueba.sh` borra los
/// que queden.
///
/// Solo funciona contra un Supabase local: estas pruebas crean usuarios y datos
/// sin parar, y nunca deben llegar a un proyecto de verdad (ver [assertLocal]).
class IntegrationHarness {
  IntegrationHarness() : _env = _readEnv() {
    assertLocal(_env['SUPABASE_URL']);
  }

  final Map<String, String> _env;
  final _clients = <SupabaseClient>[];
  final _emails = <String>[];

  /// El contenedor de la base de datos local; el nombre sale del `project_id`
  /// de supabase/config.toml. Se puede cambiar con SUPABASE_DB_CONTAINER.
  static final _dbContainer =
      Platform.environment['SUPABASE_DB_CONTAINER'] ?? 'supabase_db_mi-plata';

  /// Falla si [url] no es de un Supabase local (127.0.0.1 o localhost): con el
  /// `.env` de la nube, estas pruebas llenarían de usuarios el proyecto real.
  static void assertLocal(String? url) {
    final host = Uri.tryParse(url ?? '')?.host;
    if (host != '127.0.0.1' && host != 'localhost') {
      throw StateError(
        'Las pruebas de integración crean usuarios y datos de prueba: solo '
        'corren contra Supabase local, y SUPABASE_URL es "${url ?? ''}". '
        'Usa el .env de desarrollo (127.0.0.1).',
      );
    }
  }

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
  /// idioma con que se registra (si no se indica, no manda ninguno) y
  /// [metadata] lo demás que viaja en el registro (los datos del perfil).
  Future<SupabaseClient> signedUpClient(
    String prefix, {
    String? language,
    Map<String, Object?>? metadata,
  }) async {
    final client = newClient();
    final response = await signUp(
      client,
      prefix,
      language: language,
      metadata: metadata,
    );
    expect(response.session, isNotNull, reason: 'el registro abre sesión');
    return client;
  }

  /// Registra un usuario nuevo con [client] y devuelve la respuesta tal cual
  /// (también si el registro falla, para probar lo que la base rechaza). El
  /// correo se anota: se borra en [dispose] aunque el registro no abra sesión.
  Future<AuthResponse> signUp(
    SupabaseClient client,
    String prefix, {
    String? language,
    Map<String, Object?>? metadata,
  }) {
    final email = '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com';
    _emails.add(email);
    final data = {'language': ?language, ...?metadata};
    return client.auth.signUp(
      email: email,
      password: 'clave-segura-1',
      data: data.isEmpty ? null : data,
    );
  }

  Future<void> dispose() async {
    for (final client in _clients) {
      await client.dispose();
    }
    await _deleteUsers();
  }

  /// Borra los usuarios de prueba que creó este arnés (y, por las claves
  /// foráneas, todo lo suyo). Solo los suyos: otros archivos de prueba corren a
  /// la vez, con sus propios usuarios. Si no se puede (sin Docker, o el
  /// contenedor tiene otro nombre), avisa y no falla la prueba.
  Future<void> _deleteUsers() async {
    if (_emails.isEmpty) return;
    final list = _emails.map((e) => "'${e.replaceAll("'", "''")}'").join(', ');
    try {
      final result = await Process.run('docker', [
        'exec',
        _dbContainer,
        'psql',
        '-U',
        'postgres',
        '-v',
        'ON_ERROR_STOP=1',
        '-c',
        'delete from auth.users where email in ($list)',
      ]);
      if (result.exitCode != 0) _warn('${result.stderr}'.trim());
    } on Object catch (error) {
      _warn('$error');
    }
  }

  static void _warn(String reason) => stderr.writeln(
    'No se pudieron borrar los usuarios de prueba ($reason). '
    'Corre scripts/limpiar-usuarios-de-prueba.sh.',
  );
}
