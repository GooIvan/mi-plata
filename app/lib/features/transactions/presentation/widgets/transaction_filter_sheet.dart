import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/accounts_providers.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/categories_providers.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_type.dart';
import '../transaction_list_providers.dart';
import '../transaction_type_ui.dart';

/// Abre la hoja para elegir qué movimientos ver.
Future<void> showTransactionFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const TransactionFilterSheet(),
  );
}

/// El valor del selector de categoría que significa "sin categoría".
const _uncategorizedValue = '__sin_categoria__';

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  /// Lo que se está eligiendo; no se aplica hasta pulsar "Aplicar".
  late TransactionFilter _draft = ref.read(transactionFilterProvider);

  Future<void> _pickRange() async {
    final from = _draft.from;
    final to = _draft.to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      setState(() => _draft = _draft.withRange(picked.start, picked.end));
    }
  }

  void _apply(TransactionFilter filter) {
    ref.read(transactionFilterProvider.notifier).set(filter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    final categoryValue = _draft.uncategorized
        ? _uncategorizedValue
        : _draft.categoryId;
    final hasRange = _draft.from != null || _draft.to != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Filtrar movimientos', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('Tipo', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _draft.type == null,
                onSelected: (_) => setState(() => _draft = _draft.withType(null)),
              ),
              for (final type in TransactionType.values)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text(type.pluralLabel),
                  selected: _draft.type == type,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.withType(type)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _draft.accountId,
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las cuentas'),
              ),
              for (final account in accounts)
                DropdownMenuItem<String?>(
                  value: account.id,
                  child: Text(
                    account.isArchived
                        ? '${account.name} (archivada)'
                        : account.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _draft = _draft.withAccount(id)),
            decoration: const InputDecoration(
              labelText: 'Cuenta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: categoryValue,
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las categorías'),
              ),
              const DropdownMenuItem<String?>(
                value: _uncategorizedValue,
                child: Text('Sin categoría'),
              ),
              for (final category in categories)
                DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(
                    category.isArchived
                        ? '${category.name} (archivada)'
                        : category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(
              () => _draft = value == _uncategorizedValue
                  ? _draft.withUncategorized()
                  : _draft.withCategory(value),
            ),
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fechas',
                border: const OutlineInputBorder(),
                suffixIcon: hasRange
                    ? IconButton(
                        tooltip: 'Quitar las fechas',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(
                          () => _draft = _draft.withRange(null, null),
                        ),
                      )
                    : const Icon(Icons.date_range_outlined),
              ),
              child: Text(describeRange(_draft.from, _draft.to) ?? 'Cualquier fecha'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _apply(TransactionFilter.empty),
                  child: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => _apply(_draft),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "del 1 oct al 31 oct", "desde el 1 oct", "hasta el 31 oct"; null sin fechas.
String? describeRange(DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return 'del ${formatDayMonth(from)} al ${formatDayMonth(to)}';
  }
  if (from != null) return 'desde el ${formatDayMonth(from)}';
  if (to != null) return 'hasta el ${formatDayMonth(to)}';
  return null;
}
