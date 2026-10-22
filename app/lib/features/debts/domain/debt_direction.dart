enum DebtDirection {
  /// Yo debo.
  payable,

  /// Me deben.
  receivable;

  String get dbValue => name;

  static DebtDirection fromDb(String value) =>
      DebtDirection.values.firstWhere((direction) => direction.name == value);
}
