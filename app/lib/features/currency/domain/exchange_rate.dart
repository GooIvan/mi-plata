/// Cuánto vale una unidad de [currency] en la moneda base del usuario.
///
/// Es una sola tasa por moneda, sin historial: los totales usan la de hoy.
class ExchangeRate {
  const ExchangeRate({
    required this.currency,
    required this.rate,
    required this.updatedAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    currency: json['currency'] as String,
    rate: (json['rate'] as num).toDouble(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
  );

  final String currency;

  /// 1 [currency] = [rate] unidades de la moneda base.
  final double rate;

  /// Cuándo se definió o se cambió por última vez.
  final DateTime updatedAt;
}
