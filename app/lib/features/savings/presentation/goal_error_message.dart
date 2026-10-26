import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String goalErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        // Una cuenta tiene una sola meta activa.
        return l10n.goalsErrorAccountTaken;
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; la regla propia (una
        // tarjeta no sirve) trae un código que se traduce.
        return error.message.contains('violates check constraint')
            ? l10n.goalsErrorInvalid
            : databaseErrorMessage(l10n, error) ?? error.message;
      case '23503':
        return l10n.goalsErrorMissingAccount;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
