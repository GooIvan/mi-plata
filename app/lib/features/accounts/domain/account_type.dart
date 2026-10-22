enum AccountType {
  cash,
  bank,
  wallet,
  card;

  /// Valor guardado en la columna `type` de la base de datos.
  String get dbValue => name;

  static AccountType fromDb(String value) =>
      AccountType.values.firstWhere((type) => type.name == value);
}
