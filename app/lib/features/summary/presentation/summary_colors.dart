import 'package:flutter/material.dart';

/// Los colores de los gráficos del resumen.
///
/// Ingresos y gastos son dos series que se distinguen por identidad (no son
/// "bueno" y "malo"), así que usan las ranuras 1 y 2 de la paleta categórica,
/// validadas para daltonismo en claro y en oscuro. Los textos usan la tinta
/// del tema, nunca el color de la serie.
class SummaryColors {
  const SummaryColors._({
    required this.income,
    required this.expense,
    required this.balance,
    required this.grid,
    required this.baseline,
    required this.axisLabel,
  });

  /// Azul: ingresos.
  final Color income;

  /// Naranja: gastos.
  final Color expense;

  /// Violeta: el dinero total. No es azul ni naranja para no confundirse con
  /// los ingresos y los gastos que están en la misma pantalla.
  final Color balance;

  /// Líneas de la cuadrícula: apenas se ven.
  final Color grid;
  final Color baseline;
  final Color axisLabel;

  static const _light = SummaryColors._(
    income: Color(0xFF2A78D6),
    expense: Color(0xFFEB6834),
    balance: Color(0xFF6250D6),
    grid: Color(0xFFE1E0D9),
    baseline: Color(0xFFC3C2B7),
    axisLabel: Color(0xFF898781),
  );

  static const _dark = SummaryColors._(
    income: Color(0xFF3987E5),
    expense: Color(0xFFD95926),
    balance: Color(0xFF9085E9),
    grid: Color(0xFF2C2C2A),
    baseline: Color(0xFF383835),
    axisLabel: Color(0xFF898781),
  );

  static SummaryColors of(BuildContext context) =>
      Theme.brightnessOf(context) == Brightness.dark ? _dark : _light;
}
