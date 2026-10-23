import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String recurringErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; las reglas propias
        // (y las de los movimientos que crea un pago) traen un código que se
        // traduce.
        return error.message.contains('violates check constraint')
            ? l10n.recurringErrorInvalid
            : databaseErrorMessage(l10n, error) ?? error.message;
      case '23503':
        return databaseErrorMessage(l10n, error) ?? l10n.recurringErrorGone;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
