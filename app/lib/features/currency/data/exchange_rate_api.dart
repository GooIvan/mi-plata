import 'dart:convert';

import 'package:http/http.dart' as http;

/// Las tasas que devolvió el servicio: cuántas unidades de cada moneda valen
/// 1 dólar, y cuándo las actualizó el servicio.
class ApiRates {
  const ApiRates({required this.perUsd, required this.updatedAt});

  final Map<String, double> perUsd;
  final DateTime updatedAt;
}

/// El servicio no respondió bien (sin internet, error o respuesta rara).
class ExchangeRateApiException implements Exception {
  const ExchangeRateApiException(this.message);

  final String message;

  @override
  String toString() => 'ExchangeRateApiException: $message';
}

/// Tasas de cambio de [ExchangeRate-API](https://www.exchangerate-api.com), en su
/// versión abierta: no necesita llave, se actualiza una vez al día y pide citar
/// la fuente (la app lo hace en la pantalla de tasas).
class ExchangeRateApi {
  ExchangeRateApi({http.Client? client, Uri? url})
    : _client = client ?? http.Client(),
      _url = url ?? Uri.parse('https://open.er-api.com/v6/latest/USD');

  final http.Client _client;
  final Uri _url;

  static const _timeout = Duration(seconds: 15);

  /// Pide las tasas de hoy. Lanza [ExchangeRateApiException] si algo sale mal.
  Future<ApiRates> fetch() async {
    final http.Response response;
    try {
      response = await _client.get(_url).timeout(_timeout);
    } on Object catch (error) {
      throw ExchangeRateApiException('sin respuesta: $error');
    }
    if (response.statusCode != 200) {
      throw ExchangeRateApiException('estado ${response.statusCode}');
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['result'] != 'success') {
        throw ExchangeRateApiException('resultado ${json['result']}');
      }
      final rates = (json['rates'] as Map<String, dynamic>).map(
        (code, value) => MapEntry(code, (value as num).toDouble()),
      );
      final updated = json['time_last_update_unix'] as num?;
      return ApiRates(
        perUsd: rates,
        updatedAt: updated == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(
                updated.toInt() * 1000,
                isUtc: true,
              ).toLocal(),
      );
    } on ExchangeRateApiException {
      rethrow;
    } on Object catch (error) {
      throw ExchangeRateApiException('respuesta inválida: $error');
    }
  }

  void close() => _client.close();
}
