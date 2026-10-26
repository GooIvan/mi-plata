import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../../currency/domain/currency.dart';
import '../../../currency/presentation/currency_providers.dart';
import '../../../accounts/domain/amount_parser.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/domain/category_type.dart';
import '../../../categories/presentation/categories_providers.dart';
import '../../../transactions/domain/transaction_validators.dart';
import '../budget_error_message.dart';
import '../budgets_providers.dart';

/// Abre la hoja para definir el presupuesto mensual de una categoría.
///
/// - [categoryId] fija la categoría (al editar uno o al definir el de una
///   categoría con gasto); sin él se elige entre las que aún no tienen.
/// - [currentCents] es el presupuesto vigente, si ya hay uno.
/// - [month] es el mes desde el que rige lo que se guarde.
/// - [budgetedIds] son las categorías que ya tienen presupuesto: no se ofrecen
///   de nuevo (para cambiar uno, se toca su fila).
Future<void> showBudgetForm(
  BuildContext context, {
  required DateTime month,
  String? categoryId,
  int? currentCents,
  Set<String> budgetedIds = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BudgetFormSheet(
      month: month,
      categoryId: categoryId,
      currentCents: currentCents,
      budgetedIds: budgetedIds,
    ),
  );
}

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({
    super.key,
    required this.month,
    this.categoryId,
    this.currentCents,
    this.budgetedIds = const {},
  });

  final DateTime month;
  final String? categoryId;
  final int? currentCents;
  final Set<String> budgetedIds;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String? _categoryId = widget.categoryId;
  bool _saving = false;
  bool _amountReady = false;
  String? _error;

  bool get _isEditing => widget.currentCents != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_amountReady) {
      _amountReady = true;
      final cents = widget.currentCents;
      if (cents != null) {
        _amount.text = AmountParser.toInput(cents / 100, context.formats);
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = budgetErrorMessage(context.l10n, error);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final budgets = ref.read(budgetRulesProvider.notifier);
    await _run(
      () => budgets.setBudget(
        categoryId: _categoryId!,
        month: widget.month,
        amount: AmountParser.parse(_amount.text, context.formats)!,
      ),
    );
  }

  Future<void> _remove() async {
    final budgets = ref.read(budgetRulesProvider.notifier);
    await _run(
      () => budgets.clearBudget(categoryId: _categoryId!, month: widget.month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final currency =
        ref.watch(currencyConverterProvider).value?.base ?? defaultCurrency;
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final fixed = widget.categoryId != null;

    final options = categories
        .where(
          (category) =>
              category.type == CategoryType.expense &&
              !category.isArchived &&
              !widget.budgetedIds.contains(category.id),
        )
        .toList();
    final name = categories
        .where((category) => category.id == widget.categoryId)
        .map((category) => category.name)
        .firstOrNull;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fixed
                  ? l10n.budgetsFormTitleFixed(
                      name ?? l10n.budgetsFormTheCategory,
                    )
                  : l10n.budgetsNew,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.budgetsFormAppliesFrom(
                context.formats.monthName(widget.month),
                widget.month.year,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!fixed) ...[
              if (options.isEmpty)
                Text(
                  l10n.budgetsFormAllBudgeted,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  items: [
                    for (final category in options)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _categoryId = id),
                  validator: (id) =>
                      id == null ? l10n.budgetsFormChooseCategory : null,
                  decoration: InputDecoration(
                    labelText: l10n.budgetsFormCategoryLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              autofocus: fixed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              validator: (value) => TransactionValidators.amount(l10n, value),
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.budgetsFormAmountLabel,
                hintText: l10n.budgetsFormAmountHint,
                prefixText: '${currencySymbol(currency)} ',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || (!fixed && options.isEmpty) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _remove,
                child: Text(
                  l10n.budgetsFormRemove,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
