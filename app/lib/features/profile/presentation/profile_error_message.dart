import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/database_error.dart';
import '../../../l10n/l10n.dart';

/// Traduce un error al guardar el perfil a un mensaje para el usuario.
String profileSaveErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST301') return l10n.commonSessionExpired;
    // Los de nuestros triggers (fecha futura) traen un código que se traduce.
    return databaseErrorMessage(l10n, error) ?? l10n.profileSaveError;
  }
  return l10n.profileSaveError;
}
