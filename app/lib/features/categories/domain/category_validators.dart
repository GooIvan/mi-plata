import '../../../l10n/l10n.dart';

/// Reglas del formulario de categorías. Los mensajes llegan al usuario.
class CategoryValidators {
  const CategoryValidators._();

  static const maxNameLength = 40;

  static String? name(AppLocalizations l10n, String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return l10n.categoriesNameRequired;
    if (name.length > maxNameLength) {
      return l10n.commonNameTooLong(maxNameLength);
    }
    return null;
  }
}
