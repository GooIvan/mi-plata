import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../data/debt_repository.dart';
import '../domain/debt.dart';
import '../domain/debt_draft.dart';
import '../domain/debt_payment.dart';

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(supabaseClientProvider)),
);

final debtsProvider =
    AsyncNotifierProvider.autoDispose<DebtsNotifier, List<Debt>>(
      DebtsNotifier.new,
    );

/// Las deudas con lo pagado y lo pendiente. Las operaciones lanzan el error si
/// fallan, para que el formulario pueda avisar al usuario.
class DebtsNotifier extends AsyncNotifier<List<Debt>> {
  DebtRepository get _repository => ref.read(debtRepositoryProvider);

  @override
  Future<List<Debt>> build() {
    // Lo pagado sale de los movimientos: se recarga cuando cambian.
    ref.watch(ledgerRevisionProvider);
    return _repository.fetchAll();
  }

  /// Crea la deuda y, si trae cuenta, el movimiento del dinero.
  Future<void> create(DebtDraft draft) async {
    await _repository.create(draft);
    _moneyMoved();
  }

  Future<void> edit(
    String id, {
    required String counterparty,
    required String amount,
    DateTime? dueDate,
    String? notes,
  }) async {
    await _repository.update(
      id,
      counterparty: counterparty,
      amount: amount,
      dueDate: dueDate,
      notes: notes,
    );
    ref.invalidateSelf();
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _repository.setArchived(id, isArchived: isArchived);
    ref.invalidateSelf();
  }

  /// Registra un abono: crea el movimiento y lo enlaza a la deuda.
  Future<void> registerPayment({
    required String debtId,
    required String accountId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _repository.registerPayment(
      debtId: debtId,
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
    );
    _moneyMoved();
  }

  /// Elimina un abono borrando su movimiento (el enlace se va con él).
  Future<void> deletePayment(String transactionId) async {
    await ref.read(transactionRepositoryProvider).delete(transactionId);
    _moneyMoved();
  }

  /// Un abono o un préstamo mueven dinero: saldos, resumen y movimientos
  /// también deben recargarse.
  void _moneyMoved() => ref.read(ledgerRevisionProvider.notifier).bump();
}

/// Los abonos de una deuda.
final debtPaymentsProvider = FutureProvider.autoDispose
    .family<List<DebtPayment>, String>((ref, debtId) {
      ref.watch(ledgerRevisionProvider);
      return ref.watch(debtRepositoryProvider).fetchPayments(debtId);
    });
