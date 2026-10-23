import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../domain/transaction.dart';
import 'transaction_error_message.dart';
import 'transaction_form_screen.dart';
import 'transaction_list_providers.dart';
import 'transaction_type_ui.dart';
import 'transactions_providers.dart';
import 'widgets/transaction_filter_sheet.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  /// Lo que se espera tras la última tecla antes de buscar.
  static const _searchDelay = Duration(milliseconds: 400);

  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      final notifier = ref.read(transactionFilterProvider.notifier);
      notifier.set(ref.read(transactionFilterProvider).withText(value));
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _searching = false);
    final notifier = ref.read(transactionFilterProvider.notifier);
    notifier.set(ref.read(transactionFilterProvider).withText(null));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final page = ref.watch(transactionListProvider);
    final l10n = context.l10n;
    final filtersCount = filter.activeCount - (filter.text != null ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.transactionsSearchHint,
                  border: InputBorder.none,
                ),
              )
            : Text(l10n.transactionsTitle),
        actions: [
          if (_searching)
            IconButton(
              tooltip: l10n.transactionsSearchClose,
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else
            IconButton(
              tooltip: l10n.transactionsSearch,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            tooltip: l10n.transactionsFilter,
            icon: Badge(
              isLabelVisible: filtersCount > 0,
              label: Text('$filtersCount'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showTransactionFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (filtersCount > 0) const _ActiveFilters(),
          Expanded(
            child: page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => StateMessage(
                icon: Icons.cloud_off_outlined,
                text: transactionErrorMessage(l10n, error),
                actionLabel: l10n.commonRetry,
                onAction: () => ref.invalidate(transactionListProvider),
              ),
              data: (data) => data.items.isEmpty
                  ? _EmptyState(isFiltered: !filter.isEmpty)
                  : _TransactionList(page: data),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.transactionsNew),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    if (isFiltered) {
      return StateMessage(
        icon: Icons.search_off,
        text: l10n.transactionsNoMatches,
        actionLabel: l10n.transactionsClearFilters,
        onAction: () => ref.read(transactionFilterProvider.notifier).clear(),
      );
    }

    return StateMessage(
      icon: Icons.receipt_long_outlined,
      text: l10n.transactionsEmpty,
      actionLabel: l10n.transactionsRecordOne,
      onAction: () => showTransactionForm(context),
    );
  }
}

/// Los filtros puestos, cada uno como una etiqueta que se puede quitar.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final notifier = ref.read(transactionFilterProvider.notifier);
    final accountNames = ref.watch(accountNamesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final l10n = context.l10n;
    final range = describeRange(l10n, filter.from, filter.to);

    Widget chip(String label, VoidCallback onRemove) => InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteButtonTooltipMessage: l10n.transactionsRemoveFilter(label),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filter.type != null)
              chip(
                filter.type!.pluralLabel(l10n),
                () => notifier.set(filter.withType(null)),
              ),
            if (filter.accountId != null)
              chip(
                accountNames[filter.accountId] ?? l10n.commonAccount,
                () => notifier.set(filter.withAccount(null)),
              ),
            if (filter.uncategorized)
              chip(
                l10n.commonNoCategory,
                () => notifier.set(filter.withCategory(null)),
              )
            else if (filter.categoryId != null)
              chip(
                categoryNames[filter.categoryId] ?? l10n.commonCategory,
                () => notifier.set(filter.withCategory(null)),
              ),
            if (range != null)
              chip(range, () => notifier.set(filter.withRange(null, null))),
            TextButton(
              // Quita los filtros, pero conserva la búsqueda en curso.
              onPressed: () => notifier.set(filter.onlyText),
              child: Text(l10n.transactionsClearFilters),
            ),
          ],
        ),
      ),
    );
  }
}

/// Movimientos agrupados por día, con un encabezado en cada cambio de fecha.
/// Al llegar al final pide la página siguiente.
class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.page});

  final TransactionPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountNames = ref.watch(accountNamesProvider);
    final accountCurrencies = ref.watch(accountCurrenciesProvider);
    final categoryNames = ref.watch(categoryNamesProvider);
    final theme = Theme.of(context);

    // Cada elemento es el encabezado de un día (DateTime) o un movimiento.
    final items = <Object>[];
    DateTime? lastDay;
    for (final transaction in page.items) {
      if (lastDay == null || !DateUtils.isSameDay(lastDay, transaction.date)) {
        items.add(transaction.date);
        lastDay = transaction.date;
      }
      items.add(transaction);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length + (page.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _LoadMore(page: page);
        }

        final item = items[index];
        if (item is DateTime) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              context.formats.day(item),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final transaction = item as Transaction;
        return TransactionTile(
          transaction: transaction,
          accountNames: accountNames,
          accountCurrencies: accountCurrencies,
          categoryNames: categoryNames,
          onTap: () => showTransactionForm(context, transaction: transaction),
        );
      },
    );
  }
}

/// El final de la lista: al aparecer en pantalla pide más, y si falla ofrece
/// reintentar.
class _LoadMore extends ConsumerStatefulWidget {
  const _LoadMore({required this.page});

  final TransactionPage page;

  @override
  ConsumerState<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends ConsumerState<_LoadMore> {
  @override
  void initState() {
    super.initState();
    if (!widget.page.loadMoreFailed) _request();
  }

  /// Se pide después de dibujar: no se cambia el estado en medio de un build.
  void _request() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) ref.read(transactionListProvider.notifier).loadMore();
  });

  @override
  Widget build(BuildContext context) {
    if (widget.page.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(context.l10n.transactionsLoadMoreError),
            TextButton(
              onPressed: _request,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
