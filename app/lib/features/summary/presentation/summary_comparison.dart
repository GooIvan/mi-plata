import 'package:flutter/material.dart';

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
/// [noneNoun] ("gastos", "ingresos") hace más claro el caso en que antes no
/// había nada: "Sin gastos en septiembre" en lugar de "$0 en septiembre".
ComparisonCaption? compareWithPrevious({
  required int current,
  required int previous,
  required bool previousHasData,
  required String previousMonthName,
  String? noneNoun,
}) {
  if (!previousHasData || (current == 0 && previous == 0)) return null;

  final change = Change.between(current, previous);

  if (change.isSame) {
    return ComparisonCaption(
      text: 'Igual que en $previousMonthName',
      icon: Icons.remove,
      change: change,
    );
  }

  final fraction = change.fraction;
  final String text;
  if (fraction == null) {
    // Antes era cero: no existe un porcentaje.
    text = noneNoun == null
        ? r'$0 en ' + previousMonthName
        : 'Sin $noneNoun en $previousMonthName';
  } else {
    final percent = (fraction.abs() * 100).round();
    final amount = percent == 0 ? '<1 %' : '$percent %';
    text = change.isUp
        ? '$amount más que en $previousMonthName'
        : '$amount menos que en $previousMonthName';
  }

  return ComparisonCaption(
    text: text,
    icon: change.isUp ? Icons.arrow_upward : Icons.arrow_downward,
    change: change,
  );
}
