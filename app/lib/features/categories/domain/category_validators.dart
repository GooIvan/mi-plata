/// Reglas del formulario de categorías. Los mensajes llegan al usuario.
class CategoryValidators {
  const CategoryValidators._();

  static const maxNameLength = 40;

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Ponle un nombre a la categoría';
    if (name.length > maxNameLength) {
      return 'Usa $maxNameLength caracteres o menos';
    }
    return null;
  }
}
