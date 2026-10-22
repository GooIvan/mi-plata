import 'package:flutter/material.dart';

import '../../../core/format/money_format.dart';
import '../domain/budget_calculator.dart';

/// Los colores de estado: la paleta fija de bueno, advertencia y crítico. Nunca
/// dicen el estado solos: siempre van con un ícono y una frase.
Color budgetStatusColor(BudgetStatus status) => switch (status) {
  BudgetStatus.ok => const Color(0xFF0CA30C),
  BudgetStatus.near => const Color(0xFFFAB219),
  BudgetStatus.over => const Color(0xFFD03B3B),
};

IconData budgetStatusIcon(BudgetStatus status) => switch (status) {
  BudgetStatus.ok => Icons.check_circle_outline,
  BudgetStatus.near => Icons.warning_amber_outlined,
  BudgetStatus.over => Icons.error_outline,
};

/// La frase del estado: "Quedan $300.000", "Cerca del límite: quedan $50.000",
/// "Te pasaste por $20.000".
String budgetStatusText(BudgetStatus status, int remainingCents) {
  final amount = formatMoney(remainingCents.abs() / 100);
  return switch (status) {
    BudgetStatus.ok => 'Quedan $amount',
    BudgetStatus.near =>
      remainingCents == 0
          ? 'Llegaste al límite'
          : 'Cerca del límite: quedan $amount',
    BudgetStatus.over => 'Te pasaste por $amount',
  };
}

/// Lo que dice el aviso al registrar un gasto que acerca o pasa un presupuesto.
String budgetAlertMessage(BudgetAlert alert, String categoryName) {
  final spent = formatMoney(alert.spentAfterCents / 100);
  final limit = formatMoney(alert.limitCents / 100);

  if (alert.status == BudgetStatus.over) {
    return 'Superaste el presupuesto de $categoryName: $spent de $limit.';
  }
  final percent = (alert.spentAfterCents * 100 / alert.limitCents).floor();
  return 'Vas en $percent % del presupuesto de $categoryName ($spent de $limit).';
}

/// "1 categoría superada · 2 cerca del límite": lo que pide atención, o null si
/// ninguna categoría está cerca del límite ni lo pasó.
String? budgetAttentionText(BudgetOverview overview) {
  final over = overview.budgeted
      .where((budget) => budget.status == BudgetStatus.over)
      .length;
  final near = overview.budgeted
      .where((budget) => budget.status == BudgetStatus.near)
      .length;

  final parts = [
    if (over > 0)
      over == 1 ? '1 categoría superada' : '$over categorías superadas',
    if (near > 0) '$near cerca del límite',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
