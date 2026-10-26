import 'package:flutter/material.dart';

import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/goal_progress.dart';

/// Los colores de estado son la paleta fija de bueno y crítico; mientras se
/// ahorra, el color de la app. Nunca dicen el estado solos: van con un ícono y
/// una frase.
Color goalStatusColor(GoalStatus status, ColorScheme scheme) =>
    switch (status) {
      GoalStatus.reached => const Color(0xFF0CA30C),
      GoalStatus.overdue => const Color(0xFFD03B3B),
      GoalStatus.saving => scheme.primary,
    };

IconData goalStatusIcon(GoalStatus status) => switch (status) {
  GoalStatus.reached => Icons.check_circle_outline,
  GoalStatus.overdue => Icons.error_outline,
  GoalStatus.saving => Icons.flag_outlined,
};

/// La frase del estado: "¡Meta cumplida!", "Faltan $3.500.000 · quedan 45 días",
/// "Venció el 5 de octubre · faltan $200.000".
String goalStatusText(
  AppLocalizations l10n,
  GoalProgress progress,
  DateTime today,
) {
  final formats = Formats(l10n);
  final remaining = formats.money(
    progress.remainingCents / 100,
    currency: progress.currency,
  );

  return switch (progress.statusOn(today)) {
    GoalStatus.reached => l10n.goalsStatusReached,
    GoalStatus.overdue => l10n.goalsStatusOverdue(
      formats.fullDate(progress.goal.targetDate!),
      remaining,
    ),
    GoalStatus.saving => [
      l10n.goalsRemaining(remaining),
      if (progress.daysLeft(today) case final days?) l10n.goalsDaysLeft(days),
    ].join(' · '),
  };
}

/// "Para llegar a tiempo, ahorra $300.000 al mes."; null si no aplica (ya se
/// llegó, no hay fecha o la fecha pasó).
String? goalSuggestion(
  AppLocalizations l10n,
  GoalProgress progress,
  DateTime today,
) {
  final cents = progress.monthlyCentsNeeded(today);
  if (cents == null) return null;

  final formats = Formats(l10n);
  // Con menos de un mes no hay "al mes": se ahorra todo antes de la fecha.
  final days = progress.daysLeft(today)!;
  if (progress.monthsLeft(today) == 1 && days < 31) {
    return l10n.goalsSuggestBefore(
      formats.money(progress.remainingCents / 100, currency: progress.currency),
      formats.fullDate(progress.goal.targetDate!),
    );
  }
  return l10n.goalsSuggestMonthly(
    formats.money(cents / 100, currency: progress.currency),
  );
}
