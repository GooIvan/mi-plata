/// Cuánto vale una unidad de [currency] en la moneda base del usuario.
///
/// Es una sola tasa por moneda, sin historial: los totales usan la de hoy.
class ExchangeRate {
  const ExchangeRate({
    required this.currency,
    required this.rate,
    required this.updatedAt,
    this.isManual = true,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    currency: json['currency'] as String,
    rate: (json['rate'] as num).toDouble(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    // Una fila sin la columna (de antes de las tasas automáticas) la escribió
    // el usuario.
    isManual: (json['is_manual'] as bool?) ?? true,
  );

  final String currency;

  /// 1 [currency] = [rate] unidades de la moneda base.
  final double rate;

  /// Cuándo se definió o se cambió por última vez.
  final DateTime updatedAt;

  /// Si la escribió el usuario (manual) o la trajo el servicio de tasas
  /// (automática). Una actualización automática nunca pisa una manual.
  final bool isManual;
}
