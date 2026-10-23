import 'dart:math' as math;

import 'recurrence.dart';

/// Cómo está un pago recurrente respecto a su próxima fecha.
enum RecurringStatus {
  /// La fecha ya pasó y no se ha confirmado ni omitido.
  overdue,

  /// Toca pagarlo hoy.
  today,

  /// Falta poco: es un "pago próximo".
  soon,

  /// Todavía falta.
  later,

  /// Está en pausa: no se avisa.
  paused,

  /// Ya pasó su fecha final: no quedan pagos.
  finished,
}

/// Un pago que se repite (suscripción, arriendo...). No descuenta nada solo: la
/// app avisa cuando se acerca la fecha y el usuario confirma que pagó.
class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.accountId,
    this.categoryId,
    required this.recurrence,
    this.nextDueDate,
    required this.anchorDay,
    this.endDate,
    required this.isPaused,
    this.debtId,
    this.installments,
    this.installmentsPaid = 0,
    this.debtRemaining,
  });

  factory RecurringPayment.fromJson(Map<String, dynamic> json) =>
      RecurringPayment(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        accountId: json['account_id'] as String,
        categoryId: json['category_id'] as String?,
        recurrence: Recurrence(
          (json['every'] as num).toInt(),
          RecurrenceUnit.fromDb(json['unit'] as String),
        ),
        nextDueDate: _date(json['next_due_date']),
        anchorDay: (json['anchor_day'] as num).toInt(),
        endDate: _date(json['end_date']),
        isPaused: json['is_paused'] as bool,
        debtId: json['debt_id'] as String?,
        installments: (json['installments'] as num?)?.toInt(),
        installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
        debtRemaining: (json['debt_remaining'] as num?)?.toDouble(),
      );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Desde cuántos días antes de la fecha se considera un "pago próximo".
  static const soonDays = 7;

  final String id;
  final String name;

  /// En la moneda de [accountId]. Solo se muestra: lo que se guarda es lo que
  /// se confirme al pagar.
  final double amount;
  final String accountId;
  final String? categoryId;
  final Recurrence recurrence;

  /// El día del pago que toca; null si ya terminó.
  final DateTime? nextDueDate;

  /// El día del mes que se conserva al calcular las fechas siguientes.
  final int anchorDay;
  final DateTime? endDate;
  final bool isPaused;

  /// La deuda a la que abona, si es un plan de cuotas (una compra que se paga de
  /// a poco). Un pago normal no tiene.
  final String? debtId;

  /// Cuántas cuotas se pactaron; solo sirve para decir "cuota 4 de 12".
  final int? installments;

  /// Cuántos abonos lleva la deuda.
  final int installmentsPaid;

  /// Lo que falta por pagar de la deuda; null si no es un plan de cuotas.
  final double? debtRemaining;

  bool get isInstallmentPlan => debtId != null;

  /// La deuda ya se pagó toda: el plan no tiene más cuotas.
  bool get isSettled =>
      debtRemaining != null && (debtRemaining! * 100).round() <= 0;

  /// Qué cuota toca ("4" en "cuota 4 de 12"); null si no se pactó un número.
  /// Si se llevan más abonos que cuotas, sigue siendo la última.
  int? get currentInstallment => installments == null
      ? null
      : math.min(installmentsPaid + 1, installments!);

  /// Lo que se propone pagar la próxima vez: la cuota, o lo que falte si es
  /// menos (la última).
  double get nextAmount => debtRemaining == null || amount <= debtRemaining!
      ? amount
      : debtRemaining!;

  bool get isFinished => nextDueDate == null || isSettled;

  /// Los días que faltan para la fecha (negativo si ya pasó), contando días
  /// de calendario; null si ya terminó.
  int? daysUntilDue(DateTime today) {
    final due = nextDueDate;
    if (due == null) return null;
    return DateTime.utc(due.year, due.month, due.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  RecurringStatus statusOn(DateTime today) {
    if (isFinished) return RecurringStatus.finished;
    final days = daysUntilDue(today)!;
    if (isPaused) return RecurringStatus.paused;
    if (days < 0) return RecurringStatus.overdue;
    if (days == 0) return RecurringStatus.today;
    if (days <= soonDays) return RecurringStatus.soon;
    return RecurringStatus.later;
  }

  /// Si pide atención: está vencido, toca hoy o falta poco.
  bool needsAttention(DateTime today) => switch (statusOn(today)) {
    RecurringStatus.overdue ||
    RecurringStatus.today ||
    RecurringStatus.soon => true,
    _ => false,
  };

  /// Un pago al que todavía se le puede confirmar el siguiente.
  bool get canPay => !isFinished;
}
