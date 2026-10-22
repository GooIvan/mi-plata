import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_revision.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import '../domain/transaction_filter.dart';
import 'transactions_providers.dart';

/// El filtro de la pantalla de movimientos. Vive mientras la pantalla está
/// abierta: al volver a entrar, empieza sin filtros.
final transactionFilterProvider =
    NotifierProvider.autoDispose<TransactionFilterNotifier, TransactionFilter>(
      TransactionFilterNotifier.new,
    );

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.empty;

  void set(TransactionFilter filter) => state = filter;
  void clear() => state = TransactionFilter.empty;
}

/// Los movimientos cargados hasta ahora, de página en página.
class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Transaction> items;

  /// Falso cuando la última página llegó incompleta: no hay más que pedir.
  final bool hasMore;
  final bool isLoadingMore;

  /// La última carga de "más" falló; se puede reintentar.
  final bool loadMoreFailed;

  TransactionPage copyWith({
    List<Transaction>? items,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => TransactionPage(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

final transactionListProvider =
    AsyncNotifierProvider.autoDispose<TransactionListNotifier, TransactionPage>(
      TransactionListNotifier.new,
    );

/// La lista paginada de movimientos. Se vuelve a cargar desde la primera
/// página cuando cambia el filtro o cualquier movimiento.
class TransactionListNotifier extends AsyncNotifier<TransactionPage> {
  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  @override
  Future<TransactionPage> build() async {
    final filter = ref.watch(transactionFilterProvider);
    ref.watch(ledgerRevisionProvider);

    final items = await _repository.fetchPage(filter: filter, offset: 0);
    return TransactionPage(
      items: items,
      hasMore: items.length == TransactionRepository.pageSize,
    );
  }

  /// Pide la página siguiente y la agrega al final.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    // Si el filtro cambia mientras llega la página, esa respuesta ya no sirve.
    final filter = ref.read(transactionFilterProvider);
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final next = await _repository.fetchPage(
        filter: filter,
        offset: current.items.length,
      );
      if (!ref.mounted || ref.read(transactionFilterProvider) != filter) return;

      state = AsyncData(
        TransactionPage(
          items: [...current.items, ...next],
          hasMore: next.length == TransactionRepository.pageSize,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }
}
