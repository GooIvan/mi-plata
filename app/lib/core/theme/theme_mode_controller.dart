import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_provider.dart';

/// El modo de color que eligió el usuario: claro, oscuro, o el del teléfono
/// (por defecto).
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    // Un valor que no conocemos (o ninguno) sigue al teléfono.
    return ThemeMode.values.where((mode) => mode.name == saved).firstOrNull ??
        ThemeMode.system;
  }

  /// Cambia el modo al instante y lo recuerda; "sistema" borra la elección.
  Future<void> select(ThemeMode mode) async {
    state = mode;
    final preferences = ref.read(sharedPreferencesProvider);
    if (mode == ThemeMode.system) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, mode.name);
    }
  }
}
