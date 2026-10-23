import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un contador que sube cada vez que cambia algo que afecta a los saldos, los
/// movimientos, los totales del resumen o las deudas.
///
/// Los proveedores que muestran esos datos lo observan y se recargan solos, así
/// que ninguno tiene que importar a los otros (y no hay dependencias
/// circulares entre funciones). Quien cambia datos solo llama a [bump].
final ledgerRevisionProvider = NotifierProvider<LedgerRevision, int>(
  LedgerRevision.new,
);

class LedgerRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
