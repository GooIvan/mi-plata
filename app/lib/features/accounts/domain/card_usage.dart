import 'account.dart';

/// Qué tan cargada está una tarjeta respecto a su cupo.
enum CardLevel {
  /// Hay cupo de sobra.
  ok,

  /// Ya se usó el 80 % del cupo o más.
  high,

  /// Se pasó del cupo.
  over,
}

/// Lo que se debe en una tarjeta y lo que queda del cupo.
///
/// El saldo de una tarjeta es negativo cuando se debe: lo usado es ese valor
/// sin el signo. Un saldo positivo (se pagó de más) cuenta como cero usado.
/// Todo va en centavos enteros para no acumular error de coma flotante.
class CardUsage {
  const CardUsage._({required this.usedCents, required this.limitCents});

  factory CardUsage.of(Account account) => CardUsage._(
    usedCents: _cents(-account.currentBalance).clamp(0, 1 << 52),
    limitCents: account.creditLimit == null
        ? null
        : _cents(account.creditLimit!),
  );

  /// Lo que se debe.
  final int usedCents;

  /// El cupo; null si no se dio.
  final int? limitCents;

  bool get hasLimit => limitCents != null;

  /// Lo que queda del cupo; negativo si se pasó. Null sin cupo.
  int? get availableCents =>
      limitCents == null ? null : limitCents! - usedCents;

  /// Qué parte del cupo se usó, de 0 a 1 (más de 1 si se pasó). Null sin cupo.
  double? get ratio => limitCents == null ? null : usedCents / limitCents!;

  CardLevel get level {
    final ratio = this.ratio;
    if (ratio == null || ratio < 0.8) return CardLevel.ok;
    return ratio > 1 ? CardLevel.over : CardLevel.high;
  }

  static int _cents(double amount) => (amount * 100).round();
}
