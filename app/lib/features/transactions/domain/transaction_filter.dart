import 'transaction_type.dart';

/// Qué movimientos se quieren ver. Un filtro vacío los muestra todos.
///
/// Todas las condiciones se combinan con "y": un gasto, de esta cuenta, entre
/// estas fechas. Es inmutable: cada `with…` devuelve uno nuevo.
class TransactionFilter {
  const TransactionFilter({
    this.text,
    this.type,
    this.accountId,
    this.categoryId,
    this.uncategorized = false,
    this.from,
    this.to,
  });

  /// Texto que debe aparecer en la descripción, sin importar mayúsculas.
  final String? text;
  final TransactionType? type;

  /// Una cuenta: el movimiento sale de ella o entra a ella.
  final String? accountId;

  /// Una categoría concreta. No se combina con [uncategorized].
  final String? categoryId;

  /// Solo los movimientos sin categoría.
  final bool uncategorized;

  /// Primer y último día (incluidos); puede ir uno solo.
  final DateTime? from;
  final DateTime? to;

  static const empty = TransactionFilter();

  bool get isEmpty => activeCount == 0;

  /// Cuántos criterios están puestos. El rango de fechas cuenta como uno.
  int get activeCount =>
      (text != null ? 1 : 0) +
      (type != null ? 1 : 0) +
      (accountId != null ? 1 : 0) +
      (categoryId != null || uncategorized ? 1 : 0) +
      (from != null || to != null ? 1 : 0);

  /// Este filtro sin ningún criterio, salvo el texto que se está buscando.
  TransactionFilter get onlyText => TransactionFilter(text: text);

  /// El texto se recorta; uno vacío quita el criterio.
  TransactionFilter withText(String? value) {
    final trimmed = value?.trim();
    return TransactionFilter(
      text: trimmed == null || trimmed.isEmpty ? null : trimmed,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      uncategorized: uncategorized,
      from: from,
      to: to,
    );
  }

  TransactionFilter withType(TransactionType? value) => TransactionFilter(
    text: text,
    type: value,
    accountId: accountId,
    categoryId: categoryId,
    uncategorized: uncategorized,
    from: from,
    to: to,
  );

  TransactionFilter withAccount(String? value) => TransactionFilter(
    text: text,
    type: type,
    accountId: value,
    categoryId: categoryId,
    uncategorized: uncategorized,
    from: from,
    to: to,
  );

  /// Una categoría concreta, o null para quitar el criterio. Reemplaza
  /// "sin categoría".
  TransactionFilter withCategory(String? value) => TransactionFilter(
    text: text,
    type: type,
    accountId: accountId,
    categoryId: value,
    from: from,
    to: to,
  );

  /// Solo los movimientos sin categoría. Reemplaza una categoría concreta.
  TransactionFilter withUncategorized() => TransactionFilter(
    text: text,
    type: type,
    accountId: accountId,
    uncategorized: true,
    from: from,
    to: to,
  );

  /// Las fechas se guardan sin hora. Sin ninguna, quita el criterio.
  TransactionFilter withRange(DateTime? start, DateTime? end) =>
      TransactionFilter(
        text: text,
        type: type,
        accountId: accountId,
        categoryId: categoryId,
        uncategorized: uncategorized,
        from: start == null ? null : DateTime(start.year, start.month, start.day),
        to: end == null ? null : DateTime(end.year, end.month, end.day),
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.text == text &&
      other.type == type &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.uncategorized == uncategorized &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode =>
      Object.hash(text, type, accountId, categoryId, uncategorized, from, to);
}
