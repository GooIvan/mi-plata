import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_provider.dart';

/// Los idiomas que ofrece la app.
const supportedLanguages = ['es', 'en'];

/// El idioma que eligió el usuario, o null para seguir el del teléfono.
final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'language';

  @override
  Locale? build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return supportedLanguages.contains(saved) ? Locale(saved!) : null;
  }

  /// Cambia el idioma; null vuelve a seguir el del teléfono.
  Future<void> select(Locale? locale) async {
    state = locale;
    final preferences = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, locale.languageCode);
    }
  }
}
