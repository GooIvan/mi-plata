import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String budgetErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos. El de nuestro trigger
        // ("Solo las categorías de gasto pueden tener presupuesto") trae un
        // código que se traduce; si no se conoce, se muestra el de la base.
        return error.message.contains('violates check constraint')
            ? l10n.budgetsErrorInvalid
            : databaseErrorMessage(l10n, error) ?? error.message;
      case '23503':
        return l10n.budgetsErrorMissingCategory;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
