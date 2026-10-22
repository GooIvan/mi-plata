import 'debt_direction.dart';

enum DebtStatus {
  /// Ya no falta nada por pagar.
  settled,

  /// La fecha de vencimiento ya pasó y falta dinero.
  overdue,

  /// Vence en los próximos días.
  dueSoon,

  /// Pendiente, sin urgencia (o sin fecha de vencimiento).
  active,
}

/// Una deuda con lo pagado y lo pendiente, tal como lo calcula la vista
/// `v_debt_balances`. Los montos son `double` solo para mostrarlos.
class Debt {
  const Debt({
    required this.id,
    required this.direction,
    required this.counterparty,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.currency,
    required this.startDate,
    this.dueDate,
    this.notes,
    required this.isArchived,
  });

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'] as String,
    direction: DebtDirection.fromDb(json['direction'] as String),
    counterparty: json['counterparty'] as String,
    amount: (json['amount'] as num).toDouble(),
    paid: (json['paid'] as num).toDouble(),
    remaining: (json['remaining'] as num).toDouble(),
    currency: json['currency'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    dueDate: json['due_date'] == null
        ? null
        : DateTime.parse(json['due_date'] as String),
    notes: json['notes'] as String?,
    isArchived: json['is_archived'] as bool,
  );

  /// Cuántos días antes del vencimiento una deuda cuenta como "por vencer".
  static const dueSoonDays = 7;

  final String id;
  final DebtDirection direction;

  /// La otra persona: a quien le debo o quien me debe.
  final String counterparty;
  final double amount;
  final double paid;
  final double remaining;
  final String currency;
  final DateTime startDate;
  final DateTime? dueDate;
  final String? notes;
  final bool isArchived;

  /// Se compara en centavos: un resto de punto flotante no deja una deuda viva.
  bool get isSettled => (remaining * 100).round() <= 0;

  /// Qué parte ya se pagó, de 0 a 1.
  double get progress => amount <= 0 ? 0 : (paid / amount).clamp(0.0, 1.0);

  /// Días que faltan para el vencimiento (negativo si ya pasó), o null si no
  /// tiene fecha. Cuenta días de calendario, sin importar la hora.
  int? daysUntilDue(DateTime today) {
    final due = dueDate;
    if (due == null) return null;
    return DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  DebtStatus statusOn(DateTime today) {
    if (isSettled) return DebtStatus.settled;
    final days = daysUntilDue(today);
    if (days == null) return DebtStatus.active;
    if (days < 0) return DebtStatus.overdue;
    if (days <= dueSoonDays) return DebtStatus.dueSoon;
    return DebtStatus.active;
  }
}
