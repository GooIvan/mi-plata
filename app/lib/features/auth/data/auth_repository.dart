import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso a Supabase Auth. Es lo único que conoce el SDK de autenticación.
class AuthRepository {
  const AuthRepository(this._auth);

  final GoTrueClient _auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// Devuelve `true` si hay que confirmar el correo antes de poder entrar.
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _auth.signUp(email: email, password: password);
    return response.session == null;
  }

  Future<void> signOut() => _auth.signOut();
}
