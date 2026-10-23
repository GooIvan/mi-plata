import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/l10n.dart';

/// Traduce un error al cargar el resumen a un mensaje para el usuario.
String summaryErrorMessage(AppLocalizations l10n, Object error) {
  if (error is PostgrestException && error.code == 'PGRST301') {
    return l10n.commonSessionExpired;
  }
  return l10n.summaryLoadError;
}
