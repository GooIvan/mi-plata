import 'dart:math' as math;

import 'savings_goal.dart';

/// Cómo va una meta.
enum GoalStatus {
  /// Ya se juntó todo.
  reached,

  /// Pasó la fecha y no se juntó.
  overdue,

  /// Falta por juntar (con o sin fecha).
  saving,
}

/// Cómo va una [SavingsGoal]: lo que se lleva es el saldo de su cuenta.
///
/// Todo en centavos enteros, para no arrastrar errores de decimales. Un saldo
/// negativo (una cuenta que se pasó de gastos) cuenta como cero ahorrado.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.accountName,
    required this.currency,
    required this.balanceCents,
    this.accountArchived = false,
  });

  final SavingsGoal goal;
  final String accountName;
  final String currency;
  final int balanceCents;

  /// La cuenta de la meta se archivó: la meta sigue, pero ya no se puede
  /// ahorrar en ella.
  final bool accountArchived;

  int get targetCents => goal.targetCents;
  int get savedCents => math.max(balanceCents, 0);
  int get remainingCents => math.max(targetCents - savedCents, 0);
  bool get isReached => savedCents >= targetCents;

  /// De 0 a 1 (más allá de la meta no pasa de 1).
  double get fraction => math.min(savedCents / targetCents, 1.0);

  /// El porcentaje que se muestra: hacia abajo, para no decir "100%" antes de
  /// llegar.
  int get percent => (savedCents * 100 ~/ targetCents).clamp(0, 100);

  /// Días que faltan para la fecha de la meta (negativo si ya pasó); null si no
  /// tiene fecha.
  int? daysLeft(DateTime today) {
    final date = goal.targetDate;
    if (date == null) return null;
    return _day(date).difference(_day(today)).inDays;
  }

  GoalStatus statusOn(DateTime today) {
    if (isReached) return GoalStatus.reached;
    final days = daysLeft(today);
    if (days != null && days < 0) return GoalStatus.overdue;
    return GoalStatus.saving;
  }

  /// Meses enteros que quedan hasta la fecha, al menos uno; null si no hay
  /// fecha. El 15 de octubre al 15 de enero son 3.
  int? monthsLeft(DateTime today) {
    final date = goal.targetDate;
    if (date == null) return null;
    final from = _day(today);
    final to = _day(date);
    var months = (to.year - from.year) * 12 + to.month - from.month;
    if (to.day < from.day) months -= 1;
    return math.max(months, 1);
  }

  /// Cuánto ahorrar cada mes para llegar a tiempo; null si ya se llegó, la
  /// meta no tiene fecha o la fecha ya pasó.
  ///
  /// Redondea hacia arriba a la unidad entera ($333.334 y no $333.333,34): es
  /// lo que una persona aparta, y así nunca se queda corto. Nunca pide más de
  /// lo que falta.
  int? monthlyCentsNeeded(DateTime today) {
    if (statusOn(today) != GoalStatus.saving) return null;
    final months = monthsLeft(today);
    if (months == null) return null;

    final perMonth = (remainingCents + months - 1) ~/ months;
    final wholeUnits = (perMonth + 99) ~/ 100 * 100;
    return math.min(wholeUnits, remainingCents);
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

/// Primero las que vencen antes; las que no tienen fecha, después, por nombre.
/// Las cumplidas, al final.
int compareGoals(GoalProgress a, GoalProgress b, DateTime today) {
  int rank(GoalProgress p) => p.isReached ? 1 : 0;
  final byRank = rank(a).compareTo(rank(b));
  if (byRank != 0) return byRank;

  final dateA = a.goal.targetDate;
  final dateB = b.goal.targetDate;
  if (dateA != null && dateB != null) {
    final byDate = dateA.compareTo(dateB);
    if (byDate != 0) return byDate;
  } else if (dateA != null) {
    return -1;
  } else if (dateB != null) {
    return 1;
  }
  return a.goal.name.toLowerCase().compareTo(b.goal.name.toLowerCase());
}
