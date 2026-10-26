import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/categories/domain/category_validators.dart';
import 'package:mi_plata/features/categories/presentation/category_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  test('Category.fromJson lee una fila de categories', () {
    final category = Category.fromJson({
      'id': 'c1',
      'user_id': 'u1',
      'name': 'Mercado',
      'type': 'expense',
      'icon': null,
      'color': null,
      'is_archived': true,
      'created_at': '2026-10-22T10:00:00Z',
    });

    expect(category.id, 'c1');
    expect(category.name, 'Mercado');
    expect(category.type, CategoryType.expense);
    expect(category.isArchived, isTrue);
  });

  test('CategoryType conoce ingreso y gasto', () {
    for (final type in ['income', 'expense']) {
      expect(CategoryType.fromDb(type).dbValue, type);
    }
    expect(() => CategoryType.fromDb('transfer'), throwsStateError);
  });

  group('validador del nombre', () {
    test('es obligatorio y tiene un máximo', () {
      expect(CategoryValidators.name(l10n, 'Mascotas'), isNull);
      expect(CategoryValidators.name(l10n, '  '), 'Ponle un nombre a la categoría');
      expect(CategoryValidators.name(l10n, null), 'Ponle un nombre a la categoría');
      expect(CategoryValidators.name(l10n, 'x' * 41), 'Usa 40 caracteres o menos');
      expect(CategoryValidators.name(l10n, 'x' * 40), isNull);
    });
  });

  group('categoryErrorMessage', () {
    String message(String? code) =>
        categoryErrorMessage(l10n, PostgrestException(message: 'x', code: code));

    test('traduce los códigos de la base de datos', () {
      expect(message('23505'), 'Ya tienes una categoría activa con ese nombre.');
      expect(message('PGRST301'), startsWith('Tu sesión expiró'));
    });

    test('lo desconocido da el mensaje genérico', () {
      expect(message('XX000'), startsWith('No se pudo completar'));
      expect(categoryErrorMessage(l10n, StateError('boom')), startsWith('No se pudo'));
    });
  });
}
