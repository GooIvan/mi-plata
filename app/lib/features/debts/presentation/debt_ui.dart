import 'package:flutter/material.dart';

import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/debt.dart';
import '../domain/debt_direction.dart';

extension DebtDirectionUi on DebtDirection {
  /// La pestaña y el selector: "Debo" / "Me deben".
  String label(AppLocalizations l10n) => switch (this) {
    DebtDirection.payable => l10n.debtsTabOwe,
    DebtDirection.receivable => l10n.debtsTabOwed,
  };

  IconData get icon => switch (this) {
    DebtDirection.payable => Icons.north_east,
    DebtDirection.receivable => Icons.south_west,
  };
}

/// Cómo está una deuda en una frase: "Vence mañana", "Vencida hace 3 días"...
String debtStatusText(AppLocalizations l10n, Debt debt, DateTime today) {
  if (debt.isSettled) return l10n.debtStatusSettled;

  final days = debt.daysUntilDue(today);
  if (days == null) return l10n.debtStatusNoDueDate;
  if (days < 0) return l10n.debtStatusOverdue(-days);
  if (days == 0) return l10n.debtStatusDueToday;
  if (days == 1) return l10n.debtStatusDueTomorrow;
  if (days <= Debt.dueSoonDays) return l10n.debtStatusDueInDays(days);
  return l10n.debtStatusDueOn(Formats(l10n).dayMonth(debt.dueDate!));
}

/// El ícono que acompaña al estado: la urgencia no se dice solo con color.
IconData? debtStatusIcon(DebtStatus status) => switch (status) {
  DebtStatus.settled => Icons.check_circle_outline,
  DebtStatus.overdue => Icons.error_outline,
  DebtStatus.dueSoon => Icons.schedule,
  DebtStatus.active => null,
};

Color? debtStatusColor(DebtStatus status, ColorScheme colors) =>
    switch (status) {
      DebtStatus.settled => colors.primary,
      DebtStatus.overdue => colors.error,
      DebtStatus.dueSoon || DebtStatus.active => null,
    };

/// El orden de la lista: primero lo pendiente (lo que vence antes, arriba),
/// luego lo saldado.
int compareDebts(Debt a, Debt b) {
  if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;

  final dueA = a.dueDate;
  final dueB = b.dueDate;
  if (dueA != null && dueB != null) {
    final byDue = dueA.compareTo(dueB);
    if (byDue != 0) return byDue;
  } else if (dueA != null || dueB != null) {
    return dueA != null ? -1 : 1; // las que tienen fecha, primero
  }
  return a.counterparty.toLowerCase().compareTo(b.counterparty.toLowerCase());
}
