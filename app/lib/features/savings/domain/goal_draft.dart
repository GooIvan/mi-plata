import '../../../core/format/date_format.dart';

/// Lo que se envía para crear o editar una meta.
class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.targetAmount,
    required this.accountId,
    this.targetDate,
  });

  final String name;

  /// Un decimal exacto en texto, como lo devuelve `AmountParser`.
  final String targetAmount;
  final String accountId;
  final DateTime? targetDate;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'target_amount': targetAmount,
    'account_id': accountId,
    'target_date': targetDate == null ? null : toDbDate(targetDate!),
  };
}
