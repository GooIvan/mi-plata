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
    required this.heroLossGradient,
    required this.onHero,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;

  /// El degradado de la tarjeta principal (el dinero total).
  final List<Color> heroGradient;

  /// El degradado cuando el dinero total es negativo.
  final List<Color> heroLossGradient;

  /// El color del texto sobre los degradados.
  final Color onHero;

  static const light = FinanceColors(
    income: Color(0xFF0E9F6E),
    expense: Color(0xFFE5484D),
    transfer: Color(0xFF3E7BFA),
    warning: Color(0xFFD98A00),
    heroGradient: [Color(0xFF065F43), Color(0xFF0A8359)],
    heroLossGradient: [Color(0xFF9B1C1C), Color(0xFFD13438)],
    onHero: Color(0xFFFFFFFF),
  );

  static const dark = FinanceColors(
    income: Color(0xFF3DD6A0),
    expense: Color(0xFFFF7A7F),
    transfer: Color(0xFF7DA5FF),
    warning: Color(0xFFFFC043),
    heroGradient: [Color(0xFF0A4F3A), Color(0xFF11805A)],
    heroLossGradient: [Color(0xFF8A1C1C), Color(0xFFC72F33)],
    onHero: Color(0xFFFFFFFF),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? warning,
    List<Color>? heroGradient,
    List<Color>? heroLossGradient,
    Color? onHero,
  }) => FinanceColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
    warning: warning ?? this.warning,
    heroGradient: heroGradient ?? this.heroGradient,
    heroLossGradient: heroLossGradient ?? this.heroLossGradient,
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
      heroLossGradient: [
        for (var i = 0; i < heroLossGradient.length; i++)
          Color.lerp(heroLossGradient[i], other.heroLossGradient[i], t)!,
      ],
      onHero: Color.lerp(onHero, other.onHero, t)!,
    );
  }
}

extension FinanceColorsContext on BuildContext {
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
