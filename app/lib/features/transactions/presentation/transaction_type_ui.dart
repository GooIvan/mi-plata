import 'package:flutter/material.dart';

import '../domain/transaction_type.dart';

extension TransactionTypeUi on TransactionType {
  String get label => switch (this) {
    TransactionType.income => 'Ingreso',
    TransactionType.expense => 'Gasto',
    TransactionType.transfer => 'Transferencia',
  };

  IconData get icon => switch (this) {
    TransactionType.income => Icons.south_west,
    TransactionType.expense => Icons.north_east,
    TransactionType.transfer => Icons.swap_horiz,
  };
}
