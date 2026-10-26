import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../domain/transaction_type.dart';

extension TransactionTypeUi on TransactionType {
  String label(AppLocalizations l10n) => switch (this) {
    TransactionType.income => l10n.transactionTypeIncome,
    TransactionType.expense => l10n.transactionTypeExpense,
    TransactionType.transfer => l10n.transactionTypeTransfer,
  };

  /// Para filtros y listas: "Ingresos", "Gastos", "Transferencias".
  String pluralLabel(AppLocalizations l10n) => switch (this) {
    TransactionType.income => l10n.commonIncomes,
    TransactionType.expense => l10n.commonExpenses,
    TransactionType.transfer => l10n.commonTransfers,
  };

  IconData get icon => switch (this) {
    TransactionType.income => Icons.south_west,
    TransactionType.expense => Icons.north_east,
    TransactionType.transfer => Icons.swap_horiz,
  };
}
