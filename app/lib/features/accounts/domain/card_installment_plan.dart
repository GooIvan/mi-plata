import 'card_calendar.dart';

/// Una compra con la tarjeta diferida en cuotas, tal como la lee la vista
/// `v_card_installment_plans`.
///
/// El gasto de la tarjeta es por el total que se paga (con intereses); aquí se
/// sabe en cuántas cuotas lo cobra el banco. Lo que ya se cobró se calcula con
/// las fechas de corte de la tarjeta, no se guarda: la primera cuota entra en el
/// primer corte desde la fecha de la compra y las demás, una por mes. Las
/// cuotas son de [installmentCents] y la última es lo que falte para llegar al
/// total. Todo va en centavos enteros.
class CardInstallmentPlan {
  const CardInstallmentPlan({
    required this.id,
    required this.transactionId,
    required this.accountId,
    this.categoryId,
    this.description,
    required this.date,
    required this.totalCents,
    required this.purchaseCents,
    required this.installments,
    required this.installmentCents,
  });

  factory CardInstallmentPlan.fromJson(Map<String, dynamic> json) =>
      CardInstallmentPlan(
        id: json['id'] as String,
        transactionId: json['transaction_id'] as String,
        accountId: json['account_id'] as String,
        categoryId: json['category_id'] as String?,
        description: json['description'] as String?,
        date: DateTime.parse(json['transaction_date'] as String),
        totalCents: _cents(json['total_amount']),
        purchaseCents: _cents(json['purchase_amount']),
        installments: (json['installments'] as num).toInt(),
        installmentCents: _cents(json['installment_amount']),
      );

  final String id;

  /// El gasto de la tarjeta que registra la compra.
  final String transactionId;
  final String accountId;
  final String? categoryId;
  final String? description;

  /// El día de la compra.
  final DateTime date;

  /// Lo que se paga en total, con intereses: el monto del gasto.
  final int totalCents;

  /// Lo que costaba la compra, sin intereses.
  final int purchaseCents;
  final int installments;

  /// Lo que vale cada cuota, menos la última.
  final int installmentCents;

  int get interestCents => totalCents - purchaseCents;

  /// Lo que vale la cuota número [number] (desde 1): la última es lo que falte
  /// para llegar al total.
  int cuotaCents(int number) => number < installments
      ? installmentCents
      : totalCents - installmentCents * (installments - 1);

  /// Cuántas cuotas ya se cobraron en el extracto que cerró en [statement] (un
  /// día de corte de [calendar]), contándolo.
  int billedCuotas(CardCalendar calendar, DateTime statement) {
    final first = calendar.statementOf(date);
    if (first.isAfter(statement)) return 0;
    final months =
        (statement.year - first.year) * 12 + statement.month - first.month;
    final billed = months + 1;
    return billed > installments ? installments : billed;
  }

  /// Lo que ya se cobró en el extracto que cerró en [statement].
  int billedCents(CardCalendar calendar, DateTime statement) {
    final billed = billedCuotas(calendar, statement);
    return billed >= installments ? totalCents : billed * installmentCents;
  }

  /// Lo que todavía no se cobra tras el extracto que cerró en [statement].
  int unbilledCents(CardCalendar calendar, DateTime statement) =>
      totalCents - billedCents(calendar, statement);

  /// Ya se cobraron todas las cuotas.
  bool isFinished(CardCalendar calendar, DateTime today) =>
      billedCuotas(calendar, calendar.lastStatement(today)) >= installments;

  /// El corte en que se cobra la próxima cuota; null si ya terminó.
  DateTime? nextCuotaStatement(CardCalendar calendar, DateTime today) {
    final billed = billedCuotas(calendar, calendar.lastStatement(today));
    if (billed >= installments) return null;
    final first = calendar.statementOf(date);
    return calendar.statementIn(first.year, first.month + billed);
  }

  static int _cents(Object? value) => ((value as num) * 100).round();
}

/// Cómo quedan las cuotas de una compra: lo mismo que calcula la base de datos
/// al registrarla, para mostrarlo antes de guardar.
class CardInstallmentQuote {
  const CardInstallmentQuote._({
    required this.installmentCents,
    required this.totalCents,
    required this.valid,
  });

  /// [installmentCents] es null cuando no hay intereses: la compra se parte en
  /// partes iguales y la última absorbe los centavos.
  factory CardInstallmentQuote.of({
    required int purchaseCents,
    required int installments,
    int? installmentCents,
  }) {
    if (installments < 2 || purchaseCents <= 0) {
      return const CardInstallmentQuote._(
        installmentCents: 0,
        totalCents: 0,
        valid: false,
      );
    }
    final each = installmentCents ?? (purchaseCents / installments).round();
    final total = installmentCents == null
        ? purchaseCents
        : (each * installments > purchaseCents
              ? each * installments
              : purchaseCents);
    // Las cuotas que se escriben no pueden sumar menos que la compra, salvo los
    // centavos del redondeo; y cada una vale algo y deja algo para la última.
    final coversPurchase =
        installmentCents == null ||
        each * installments >= purchaseCents - installments;
    return CardInstallmentQuote._(
      installmentCents: each,
      totalCents: total,
      valid: coversPurchase && each > 0 && each * (installments - 1) < total,
    );
  }

  final int installmentCents;

  /// Lo que se paga en total, con intereses.
  final int totalCents;

  /// Si las cuotas cuadran con la compra.
  final bool valid;
}
