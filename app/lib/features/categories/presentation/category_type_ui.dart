import 'package:flutter/material.dart';

import '../domain/category_type.dart';

extension CategoryTypeUi on CategoryType {
  /// Para títulos: "gasto" / "ingreso".
  String get label => switch (this) {
    CategoryType.expense => 'gasto',
    CategoryType.income => 'ingreso',
  };

  IconData get icon => switch (this) {
    CategoryType.expense => Icons.north_east,
    CategoryType.income => Icons.south_west,
  };
}
