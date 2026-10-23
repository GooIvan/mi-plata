import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String debtErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos. Los de nuestros
        // triggers y funciones ("El abono supera lo que falta por pagar")
        // traen un código que se traduce; si no se conoce, se muestra el de
        // la base.
        return error.message.contains('violates check constraint')
            ? l10n.debtsErrorInvalid
            : databaseErrorMessage(l10n, error) ?? error.message;
      case '23503':
        return databaseErrorMessage(l10n, error) ??
            l10n.debtsErrorMissingReference;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
