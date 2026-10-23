import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_draft.dart';
import '../domain/recurring_payment.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(supabaseClientProvider)),
);

final recurringPaymentsProvider =
    AsyncNotifierProvider.autoDispose<
      RecurringPaymentsNotifier,
      List<RecurringPayment>
    >(RecurringPaymentsNotifier.new);

/// Los pagos recurrentes. Las operaciones lanzan el error si fallan, para que
/// el formulario pueda avisar al usuario.
class RecurringPaymentsNotifier extends AsyncNotifier<List<RecurringPayment>> {
  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  @override
  Future<List<RecurringPayment>> build() => _repository.fetchAll();

  Future<void> create(RecurringDraft draft) async {
    await _repository.create(draft);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, RecurringDraft draft) async {
    await _repository.update(id, draft);
    ref.invalidateSelf();
  }

  Future<void> setPaused(String id, {required bool paused}) async {
    await _repository.setPaused(id, paused: paused);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    ref.invalidateSelf();
  }

  /// Confirmar un pago crea un gasto de verdad: los saldos, el resumen y los
  /// presupuestos se recargan (ver [ledgerRevisionProvider]).
  Future<void> confirm({
    required String id,
    required String accountId,
    required String amount,
    required DateTime date,
    String? description,
  }) async {
    await _repository.confirm(
      id: id,
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
    );
    ref.read(ledgerRevisionProvider.notifier).bump();
    ref.invalidateSelf();
  }

  Future<void> skip(String id) async {
    await _repository.skip(id);
    ref.invalidateSelf();
  }
}

/// Los gastos que se registraron al confirmar los pagos de una regla.
final recurringHistoryProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, id) {
      ref.watch(ledgerRevisionProvider);
      return ref.watch(recurringRepositoryProvider).fetchPayments(id);
    });
