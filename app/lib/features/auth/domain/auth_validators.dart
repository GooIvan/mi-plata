/// Reglas de los formularios de acceso. Los mensajes llegan al usuario.
class AuthValidators {
  const AuthValidators._();

  /// Debe coincidir con `minimum_password_length` de supabase/config.toml.
  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    if (!_emailPattern.hasMatch(email)) return 'El correo no es válido';
    return null;
  }

  /// Al iniciar sesión solo se exige que no esté vacía.
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Crea una contraseña';
    if (value.length < minPasswordLength) {
      return 'Usa al menos $minPasswordLength caracteres';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) return 'Repite tu contraseña';
    if (value != password) return 'Las contraseñas no coinciden';
    return null;
  }
}
