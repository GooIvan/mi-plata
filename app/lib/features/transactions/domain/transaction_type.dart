enum TransactionType {
  income,
  expense,
  transfer;

  String get dbValue => name;

  static TransactionType fromDb(String value) =>
      TransactionType.values.firstWhere((type) => type.name == value);
}
