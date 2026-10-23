import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String debtErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; los de nuestros
        // triggers y funciones ("El abono supera lo que falta por pagar")
        // ya vienen en español y se muestran tal cual.
        return error.message.contains('violates check constraint')
            ? l10n.debtsErrorInvalid
            : error.message;
      case '23503':
        return l10n.debtsErrorMissingReference;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
