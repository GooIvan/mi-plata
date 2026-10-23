import 'package:flutter/material.dart';

import '../domain/category_type.dart';

extension CategoryTypeUi on CategoryType {
  IconData get icon => switch (this) {
    CategoryType.expense => Icons.north_east,
    CategoryType.income => Icons.south_west,
  };
}
