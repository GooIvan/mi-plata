import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/domain/profile_data.dart';

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

  /// Cambia la contraseña de la sesión abierta.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Devuelve `true` si hay que confirmar el correo antes de poder entrar.
  ///
  /// [language] ("es" o "en") viaja en los metadatos del usuario: la base lo usa
  /// para crear sus categorías por defecto en ese idioma. [profile] viaja igual:
  /// la base arma el perfil con esos datos en la misma transacción que la
  /// cuenta, así que no puede quedar una a medias.
  Future<bool> signUp({
    required String email,
    required String password,
    required String language,
    ProfileData? profile,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'language': language, ...?profile?.toSignUpMetadata()},
    );
    return response.session == null;
  }

  Future<void> signOut() => _auth.signOut();
}
