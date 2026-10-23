import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String budgetErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        // Las restricciones CHECK dan mensajes técnicos; el de nuestro trigger
        // ("Solo las categorías de gasto pueden tener presupuesto") ya viene en
        // español y se muestra tal cual.
        return error.message.contains('violates check constraint')
            ? l10n.budgetsErrorInvalid
            : error.message;
      case '23503':
        return l10n.budgetsErrorMissingCategory;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
