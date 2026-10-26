import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/l10n.dart';

/// Traduce un error de la base de datos a un mensaje para el usuario.
String categoryErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return l10n.categoriesErrorDuplicateName;
      case '23514':
        return l10n.categoriesErrorInvalidData;
      case 'PGRST301':
        return l10n.commonSessionExpired;
    }
  }
  return l10n.commonLoadError;
}
