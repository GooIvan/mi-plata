import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../currency/presentation/currency_providers.dart';
import '../../currency/presentation/currency_ui.dart';
import '../../currency/presentation/widgets/base_currency_sheet.dart';

/// Ajustes de la app: la apariencia, el idioma, la moneda y la sesión.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Lo que representa "seguir el idioma del teléfono" en el selector.
  static const _system = 'system';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final selected = ref.watch(localeControllerProvider)?.languageCode;
    final themeMode = ref.watch(themeModeControllerProvider);
    final base = ref.watch(currencyConverterProvider).value?.base;
    // Es un extra: mientras carga o si falla, la tarjeta del perfil no dice más.
    final profile = ref.watch(profileProvider).value;
    final name = [profile?.firstName, profile?.lastName]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  (name.isNotEmpty ? name : (auth.currentUser?.email ?? '?'))[0]
                      .toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(name.isNotEmpty ? name : l10n.settingsProfile),
              subtitle: Text(
                name.isNotEmpty
                    ? (auth.currentUser?.email ?? l10n.settingsProfile)
                    : l10n.settingsProfileIncomplete,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.profile),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
            child: Text(
              l10n.settingsAppearance,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeControllerProvider.notifier).select(value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text(l10n.settingsThemeSystem),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text(l10n.settingsThemeLight),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text(l10n.settingsThemeDark),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
            child: Text(
              l10n.settingsLanguage,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: RadioGroup<String>(
              groupValue: selected ?? _system,
              onChanged: (value) => ref
                  .read(localeControllerProvider.notifier)
                  .select(value == null || value == _system ? null : Locale(value)),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: _system,
                    title: Text(l10n.settingsLanguageSystem),
                  ),
                  RadioListTile<String>(
                    value: 'es',
                    title: Text(l10n.settingsLanguageSpanish),
                  ),
                  RadioListTile<String>(
                    value: 'en',
                    title: Text(l10n.settingsLanguageEnglish),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
            child: Text(
              l10n.settingsCurrency,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(l10n.settingsBaseCurrency),
                  subtitle: base == null
                      ? null
                      : Text(
                          l10n.settingsBaseCurrencyValue(
                            base,
                            currencyName(l10n, base),
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: base == null
                      ? null
                      : () => showBaseCurrencySheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(l10n.settingsExchangeRates),
                  subtitle: Text(l10n.settingsExchangeRatesHelp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.rates),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
            child: Text(
              l10n.settingsSession,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (auth.currentUser?.email case final email?)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(l10n.settingsSignedInAs(email)),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.settingsSignOut),
                  onTap: auth.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
