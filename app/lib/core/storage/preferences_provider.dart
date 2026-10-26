import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las preferencias guardadas en el teléfono. Se abren una vez en `main` y se
/// entregan aquí; las pruebas ponen las suyas.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Falta abrir las preferencias en main'),
);
