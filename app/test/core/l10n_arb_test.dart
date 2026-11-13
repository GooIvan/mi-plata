import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Los textos que no son metadatos (`@clave`) ni de configuración (`@@locale`).
Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final entry in arb.entries)
    if (!entry.key.startsWith('@')) entry.key: entry.value as String,
};

/// Los placeholders de un mensaje ICU: lo que va entre llaves y no es una rama
/// de plural/select ("one{...}").
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)(?:,[^{}]*)?\}').allMatches(message))
    match.group(1)!,
  for (final match in RegExp(r'\{(\w+),\s*(?:plural|select)').allMatches(message))
    match.group(1)!,
};

void main() {
  final es = _messages(_load('es'));
  final en = _messages(_load('en'));

  test('español e inglés tienen exactamente las mismas claves', () {
    expect(en.keys.toSet().difference(es.keys.toSet()), isEmpty, reason: 'sobran en inglés');
    expect(es.keys.toSet().difference(en.keys.toSet()), isEmpty, reason: 'faltan en inglés');
  });

  test('ningún texto está vacío', () {
    for (final entry in [...es.entries, ...en.entries]) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('cada texto usa los mismos placeholders en los dos idiomas', () {
    for (final key in es.keys) {
      expect(
        _placeholders(en[key]!),
        _placeholders(es[key]!),
        reason: 'placeholders distintos en "$key"',
      );
    }
  });

  test('las clases generadas están al día (se corrió flutter gen-l10n)', () {
    final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final missing = [
      for (final key in es.keys)
        if (!RegExp('\\b$key\\b').hasMatch(generated)) key,
    ];
    expect(missing, isEmpty, reason: 'corre `flutter gen-l10n` en app/');
  });

  test('el inglés no se quedó con el texto en español', () {
    // Salvo lo que es igual en los dos idiomas (nombres propios, números).
    const sameInBoth = {
      'settingsLanguageSpanish',
      'settingsLanguageEnglish',
      'debtsTotalAmount',
      'summaryTrendTooltip',
      'currencyNameEur',
      'currencyOption',
      'settingsBaseCurrencyValue',
      'ratesOneEquals',
      'transactionsImpliedRate',
      'dashboardCardDueOn',
      'ratesTagManual',
    };
    final untranslated = [
      for (final key in es.keys)
        if (es[key] == en[key] && !sameInBoth.contains(key)) key,
    ];
    expect(untranslated, isEmpty);
  });
}
