import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/l10n.dart';

/// Traduce un error de autenticación a un mensaje para el usuario.
String authErrorMessage(AppLocalizations l10n, Object error) {
  if (error is AuthRetryableFetchException) return l10n.authErrorOffline;
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return l10n.authErrorInvalidCredentials;
      case 'user_already_exists':
      case 'email_exists':
        return l10n.authErrorEmailExists;
      case 'weak_password':
        return l10n.authErrorWeakPassword;
      case 'email_not_confirmed':
        return l10n.authErrorEmailNotConfirmed;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return l10n.authErrorRateLimit;
      case 'signup_disabled':
        return l10n.authErrorSignupDisabled;
    }
  }
  return l10n.authErrorGeneric;
}
