import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/card_installment_draft.dart';
import '../domain/card_installment_plan.dart';

/// Acceso a las compras diferidas en cuotas con tarjeta. Lee de
/// `v_card_installment_plans` y registra con `create_card_installment_purchase`,
/// que crea el gasto y su plan juntos.
class CardInstallmentRepository {
  const CardInstallmentRepository(this._client);

  final SupabaseClient _client;

  /// Todos los planes, los más recientes primero.
  Future<List<CardInstallmentPlan>> fetchAll() async {
    final rows = await _client
        .from('v_card_installment_plans')
        .select()
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(CardInstallmentPlan.fromJson).toList();
  }

  Future<void> createPurchase(CardInstallmentDraft draft) async {
    await _client.rpc<dynamic>(
      'create_card_installment_purchase',
      params: draft.toRpcParams(),
    );
  }
}
