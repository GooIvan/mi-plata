import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos al cambiar tasas o la moneda base.
String currencyErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; las reglas propias
        // traen un código que se traduce.
        return error.message.contains('violates check constraint')
            ? l10n.ratesErrorInvalid
            : databaseErrorMessage(l10n, error) ?? error.message;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
