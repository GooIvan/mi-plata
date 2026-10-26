import 'package:flutter/material.dart';

import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
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
String budgetStatusText(
  AppLocalizations l10n,
  BudgetStatus status,
  int remainingCents, {
  required String currency,
}) {
  final amount = Formats(l10n).money(
    remainingCents.abs() / 100,
    currency: currency,
  );
  return switch (status) {
    BudgetStatus.ok => l10n.budgetsStatusOk(amount),
    BudgetStatus.near =>
      remainingCents == 0
          ? l10n.budgetsStatusAtLimit
          : l10n.budgetsStatusNear(amount),
    BudgetStatus.over => l10n.budgetsStatusOver(amount),
  };
}

/// Lo que dice el aviso al registrar un gasto que acerca o pasa un presupuesto.
String budgetAlertMessage(
  AppLocalizations l10n,
  BudgetAlert alert,
  String categoryName, {
  required String currency,
}) {
  final formats = Formats(l10n);
  final spent = formats.money(alert.spentAfterCents / 100, currency: currency);
  final limit = formats.money(alert.limitCents / 100, currency: currency);

  if (alert.status == BudgetStatus.over) {
    return l10n.budgetsAlertOver(categoryName, spent, limit);
  }
  final percent = (alert.spentAfterCents * 100 / alert.limitCents).floor();
  return l10n.budgetsAlertNear(percent, categoryName, spent, limit);
}

/// "1 categoría superada · 2 cerca del límite": lo que pide atención, o null si
/// ninguna categoría está cerca del límite ni lo pasó.
String? budgetAttentionText(AppLocalizations l10n, BudgetOverview overview) {
  final over = overview.budgeted
      .where((budget) => budget.status == BudgetStatus.over)
      .length;
  final near = overview.budgeted
      .where((budget) => budget.status == BudgetStatus.near)
      .length;

  final parts = [
    if (over > 0) l10n.budgetsOverCount(over),
    if (near > 0) l10n.budgetsNearCount(near),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
