import '../../../l10n/l10n.dart';

/// Reglas de los formularios de acceso. Los mensajes llegan al usuario.
class AuthValidators {
  const AuthValidators._();

  /// Debe coincidir con `minimum_password_length` de supabase/config.toml.
  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(AppLocalizations l10n, String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.authEmailRequired;
    if (!_emailPattern.hasMatch(email)) return l10n.authEmailInvalid;
    return null;
  }

  /// Al iniciar sesión solo se exige que no esté vacía.
  static String? requiredPassword(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.authPasswordRequired;
    return null;
  }

  static String? newPassword(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.authNewPasswordRequired;
    if (value.length < minPasswordLength) {
      return l10n.authPasswordTooShort(minPasswordLength);
    }
    return null;
  }

  static String? passwordConfirmation(
    AppLocalizations l10n,
    String? value,
    String password,
  ) {
    if (value == null || value.isEmpty) return l10n.authPasswordRepeatRequired;
    if (value != password) return l10n.authPasswordMismatch;
    return null;
  }
}
