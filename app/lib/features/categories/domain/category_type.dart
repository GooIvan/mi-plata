enum CategoryType {
  income,
  expense;

  String get dbValue => name;

  static CategoryType fromDb(String value) =>
      CategoryType.values.firstWhere((type) => type.name == value);
}
