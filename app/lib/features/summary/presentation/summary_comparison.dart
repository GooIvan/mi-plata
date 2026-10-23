import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/month_summary.dart';

/// Una frase que compara una cifra con la del mes anterior, con su ícono.
class ComparisonCaption {
  const ComparisonCaption({
    required this.text,
    required this.icon,
    required this.change,
  });

  /// "12 % más que en septiembre".
  final String text;
  final IconData icon;
  final Change change;

  /// El color del ícono: verde si el cambio es bueno, rojo si es malo, y
  /// ninguno si no cambió. Nunca es lo único que dice si fue bueno o malo: el
  /// texto y la flecha también lo dicen.
  Color? color(ColorScheme colors, {required bool upIsGood}) {
    if (change.isSame) return null;
    return change.isUp == upIsGood ? colors.primary : colors.error;
  }
}

/// Compara [current] con [previous] (ambos en centavos).
///
/// Devuelve null cuando no hay nada útil que decir: el mes anterior no tuvo
/// movimientos ([previousHasData] falso), o la cifra fue cero en los dos meses.
///
/// [noneKind] (gasto o ingreso) hace más claro el caso en que antes no había
/// nada: "Sin gastos en septiembre" en lugar de "$0 en septiembre".
ComparisonCaption? compareWithPrevious(
  AppLocalizations l10n, {
  required int current,
  required int previous,
  required bool previousHasData,
  required String previousMonthName,
  TransactionType? noneKind,
}) {
  if (!previousHasData || (current == 0 && previous == 0)) return null;

  final change = Change.between(current, previous);

  if (change.isSame) {
    return ComparisonCaption(
      text: l10n.summarySameAs(previousMonthName),
      icon: Icons.remove,
      change: change,
    );
  }

  final fraction = change.fraction;
  final String text;
  if (fraction == null) {
    // Antes era cero: no existe un porcentaje.
    text = switch (noneKind) {
      TransactionType.expense => l10n.summaryNoExpensesIn(previousMonthName),
      TransactionType.income => l10n.summaryNoIncomeIn(previousMonthName),
      _ => l10n.summaryZeroIn(previousMonthName),
    };
  } else {
    final percent = (fraction.abs() * 100).round();
    final amount = percent == 0
        ? l10n.commonPercentUnderOne
        : l10n.commonPercent(percent);
    text = change.isUp
        ? l10n.summaryMoreThan(amount, previousMonthName)
        : l10n.summaryLessThan(amount, previousMonthName);
  }

  return ComparisonCaption(
    text: text,
    icon: change.isUp ? Icons.arrow_upward : Icons.arrow_downward,
    change: change,
  );
}
