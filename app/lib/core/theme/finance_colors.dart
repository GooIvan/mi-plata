import 'package:flutter/material.dart';

/// Los colores con significado de dinero: lo que entra, lo que sale, lo que se
/// mueve entre cuentas y los avisos. Viven en el tema para que cambien solos
/// entre claro y oscuro.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warning,
    required this.heroGradient,
    required this.onHero,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;

  /// El degradado de la tarjeta principal (el dinero total).
  final List<Color> heroGradient;

  /// El color del texto sobre [heroGradient].
  final Color onHero;

  static const light = FinanceColors(
    income: Color(0xFF0E9F6E),
    expense: Color(0xFFE5484D),
    transfer: Color(0xFF3E7BFA),
    warning: Color(0xFFD98A00),
    heroGradient: [Color(0xFF0B7D57), Color(0xFF14B37D)],
    onHero: Color(0xFFFFFFFF),
  );

  static const dark = FinanceColors(
    income: Color(0xFF3DD6A0),
    expense: Color(0xFFFF7A7F),
    transfer: Color(0xFF7DA5FF),
    warning: Color(0xFFFFC043),
    heroGradient: [Color(0xFF0B5F45), Color(0xFF138A62)],
    onHero: Color(0xFFFFFFFF),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? warning,
    List<Color>? heroGradient,
    Color? onHero,
  }) => FinanceColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
    warning: warning ?? this.warning,
    heroGradient: heroGradient ?? this.heroGradient,
    onHero: onHero ?? this.onHero,
  );

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          Color.lerp(heroGradient[i], other.heroGradient[i], t)!,
      ],
      onHero: Color.lerp(onHero, other.onHero, t)!,
    );
  }
}

extension FinanceColorsContext on BuildContext {
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
