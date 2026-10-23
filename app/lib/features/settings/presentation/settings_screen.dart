import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_providers.dart';

/// Ajustes de la app: el idioma y la sesión.
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
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
