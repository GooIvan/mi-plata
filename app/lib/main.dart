import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/format/formats.dart';
import 'core/riverpod/no_retry.dart';
import 'core/storage/preferences_provider.dart';
import 'features/currency/presentation/rates_refresh.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final locale in dateLocales) {
    await initializeDateFormatting(locale);
  }
  final preferences = await SharedPreferences.getInstance();
  await dotenv.load();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(
    ProviderScope(
      retry: noRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // En la app de verdad, las tasas se actualizan solas al abrirla.
        automaticRatesOnOpenProvider.overrideWithValue(true),
      ],
      child: const MiPlataApp(),
    ),
  );
}
