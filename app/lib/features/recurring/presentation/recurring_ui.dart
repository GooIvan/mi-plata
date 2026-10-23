import 'package:flutter/material.dart';

import '../../../core/format/formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/recurrence.dart';
import '../domain/recurring_payment.dart';

/// "Cada mes", "Cada 2 semanas", "Cada año".
String recurrenceLabel(AppLocalizations l10n, Recurrence recurrence) =>
    switch (recurrence.unit) {
      RecurrenceUnit.week => l10n.recurrenceEveryWeek(recurrence.every),
      RecurrenceUnit.month => l10n.recurrenceEveryMonth(recurrence.every),
      RecurrenceUnit.year => l10n.recurrenceEveryYear(recurrence.every),
    };

/// Cada cuánto, y en un plan de cuotas también cuál toca: "Cuota 4 de 12 ·
/// Cada mes".
String recurrenceSummary(AppLocalizations l10n, RecurringPayment payment) {
  final every = recurrenceLabel(l10n, payment.recurrence);
  final number = payment.currentInstallment;
  return number == null
      ? every
      : '${l10n.installmentNumber(number, payment.installments!)} · $every';
}

/// Cómo está un pago en una frase: "Pago próximo: vence en 3 días",
/// "Vencido hace 2 días", "Próximo pago el 5 nov"...
String recurringStatusText(
  AppLocalizations l10n,
  RecurringPayment payment,
  DateTime today,
) {
  final days = payment.daysUntilDue(today);
  return switch (payment.statusOn(today)) {
    RecurringStatus.finished => l10n.recurringStatusFinished,
    RecurringStatus.paused => l10n.recurringStatusPaused,
    RecurringStatus.overdue => l10n.recurringStatusOverdue(-days!),
    RecurringStatus.today => l10n.recurringStatusToday,
    RecurringStatus.soon =>
      days == 1
          ? l10n.recurringStatusTomorrow
          : l10n.recurringStatusSoon(days!),
    RecurringStatus.later => l10n.recurringStatusLater(
      Formats(l10n).dayMonth(payment.nextDueDate!),
    ),
  };
}

/// El ícono que acompaña al estado: la urgencia no se dice solo con color.
IconData recurringStatusIcon(RecurringStatus status) => switch (status) {
  RecurringStatus.overdue => Icons.error_outline,
  RecurringStatus.today || RecurringStatus.soon => Icons.schedule,
  RecurringStatus.later => Icons.event_outlined,
  RecurringStatus.paused => Icons.pause_circle_outline,
  RecurringStatus.finished => Icons.check_circle_outline,
};

/// El color del ícono y de la frase; null es el color normal del texto.
Color? recurringStatusColor(RecurringStatus status, ColorScheme colors) =>
    switch (status) {
      RecurringStatus.overdue => colors.error,
      RecurringStatus.today || RecurringStatus.soon => const Color(0xFFB87A00),
      _ => null,
    };

/// Lo que va primero en la lista: lo que pide atención, luego lo que falta, y
/// al final lo pausado y lo terminado. Con igual estado, la fecha más cercana.
int compareRecurring(RecurringPayment a, RecurringPayment b, DateTime today) {
  int rank(RecurringPayment p) => switch (p.statusOn(today)) {
    RecurringStatus.overdue || RecurringStatus.today || RecurringStatus.soon => 0,
    RecurringStatus.later => 1,
    RecurringStatus.paused => 2,
    RecurringStatus.finished => 3,
  };
  final byRank = rank(a).compareTo(rank(b));
  if (byRank != 0) return byRank;

  final dueA = a.nextDueDate;
  final dueB = b.nextDueDate;
  if (dueA != null && dueB != null) {
    final byDue = dueA.compareTo(dueB);
    if (byDue != 0) return byDue;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
