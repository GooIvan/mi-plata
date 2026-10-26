import 'dart:async';

import 'package:mi_plata/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session fakeSession(String email) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: email,
  ),
);

/// Sustituye a [AuthRepository] en las pruebas, sin tocar Supabase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? signedInAs})
    : _session = signedInAs == null ? null : fakeSession(signedInAs);

  Session? _session;
  final _changes = StreamController<AuthState>.broadcast();

  /// Error que lanzarán signIn y signUp mientras no sea null.
  Object? error;

  /// Si es true, signUp no abre sesión (falta confirmar el correo).
  bool confirmationRequired = false;

  final calls = <String>[];

  /// El idioma con que se registró el último usuario.
  String? signedUpWithLanguage;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Stream<AuthState> get authStateChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    if (error != null) throw error!;
    _open(email);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String language,
  }) async {
    calls.add('signUp:$email');
    signedUpWithLanguage = language;
    if (error != null) throw error!;
    if (confirmationRequired) return true;
    _open(email);
    return false;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _session = null;
    _changes.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void _open(String email) {
    _session = fakeSession(email);
    _changes.add(AuthState(AuthChangeEvent.signedIn, _session));
  }
}
