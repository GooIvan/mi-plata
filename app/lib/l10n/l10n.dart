import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// Los textos de la app en el idioma actual.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
