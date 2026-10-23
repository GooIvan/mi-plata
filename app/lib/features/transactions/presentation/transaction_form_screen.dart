import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formats.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../budgets/presentation/budget_expense_alert.dart';
import '../../categories/domain/category.dart';
import '../../categories/domain/category_type.dart';
import '../../categories/presentation/categories_providers.dart';
import '../domain/negative_balance_check.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';
import '../domain/transaction_type.dart';
import '../domain/transaction_validators.dart';
import 'negative_balance_dialog.dart';
import 'negative_balance_message.dart';
import 'transaction_error_message.dart';
import 'transaction_type_ui.dart';
import 'transactions_providers.dart';

/// Abre el formulario para registrar un movimiento, o para editar [transaction].
Future<void> showTransactionForm(
  BuildContext context, {
  Transaction? transaction,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TransactionFormScreen(transaction: transaction),
    ),
  );
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late final _description = TextEditingController(
    text: widget.transaction?.description,
  );
  late TransactionType _type =
      widget.transaction?.type ?? TransactionType.expense;
  late String? _accountId = widget.transaction?.accountId;
  late String? _destinationId = widget.transaction?.destinationAccountId;
  late String? _categoryId = widget.transaction?.categoryId;
  late DateTime _date = widget.transaction?.date ?? DateTime.now();
  bool _saving = false;
  bool _amountReady = false;
  String? _error;

  bool get _isEditing => widget.transaction != null;
  bool get _isTransfer => _type == TransactionType.transfer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_amountReady) {
      _amountReady = true;
      final transaction = widget.transaction;
      if (transaction != null) {
        _amount.text = AmountParser.toInput(
          transaction.amount,
          context.formats,
        );
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: context.l10n.transactionsDateHelp,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _description.text.trim();
    final draft = TransactionDraft(
      type: _type,
      accountId: _accountId!,
      destinationAccountId: _isTransfer ? _destinationId : null,
      categoryId: _isTransfer ? null : _categoryId,
      amount: AmountParser.parse(_amount.text, context.formats)!,
      date: _date,
      description: description.isEmpty ? null : description,
    );

    final warnings = NegativeBalanceCheck.after(
      accounts: ref.read(accountsProvider).value ?? const <Account>[],
      draft: draft,
      previous: widget.transaction,
    );
    if (warnings.isNotEmpty && !await _confirmNegativeBalance(warnings)) return;
    if (!mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final transactions = ref.read(transactionsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      // Antes de guardar: después, el gasto ya estaría sumado en el mes.
      final budgetAlert = await budgetAlertBeforeSaving(
        ref,
        l10n,
        draft: draft,
        previous: widget.transaction,
      );
      if (_isEditing) {
        await transactions.edit(widget.transaction!.id, draft);
      } else {
        await transactions.create(draft);
      }
      if (mounted) Navigator.of(context).pop();
      if (budgetAlert != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(budgetAlert),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = transactionErrorMessage(l10n, error);
      });
    }
  }

  /// Avisa que el cambio deja cuentas en negativo; devuelve si el usuario
  /// quiere guardar de todos modos.
  Future<bool> _confirmNegativeBalance(List<NegativeBalance> warnings) =>
      confirmNegativeBalance(
        context,
        warnings,
        title: _isEditing
            ? context.l10n.negativeBalanceSaveTitle
            : context.l10n.negativeBalanceRecordTitle,
        confirmLabel: _isEditing
            ? context.l10n.negativeBalanceSaveAnyway
            : context.l10n.negativeBalanceRecordAnyway,
      );

  Future<void> _confirmDelete() async {
    final warnings = NegativeBalanceCheck.after(
      accounts: ref.read(accountsProvider).value ?? const <Account>[],
      previous: widget.transaction,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.transactionsDeleteTitle),
        content: Text(
          warnings.isEmpty
              ? context.l10n.transactionsDeleteBody
              : context.l10n.transactionsDeleteBodyWithWarning(
                  negativeBalanceMessage(context.l10n, warnings),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref
          .read(transactionsProvider.notifier)
          .delete(widget.transaction!.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = transactionErrorMessage(l10n, error);
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.transactionsDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.transactionsEdit : l10n.transactionsNew),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.transactionsDeleteTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: switch ((accounts, categories)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          StateMessage(
            icon: Icons.cloud_off_outlined,
            text: transactionErrorMessage(l10n, error),
            actionLabel: l10n.commonRetry,
            onAction: () {
              ref.invalidate(accountsProvider);
              ref.invalidate(categoriesProvider);
            },
          ),
        (AsyncData(value: final accounts), AsyncData(value: final categories)) =>
          _buildForm(accounts, categories),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(List<Account> allAccounts, List<Category> allCategories) {
    final l10n = context.l10n;
    // Una cuenta archivada solo se ofrece si el movimiento que se edita ya la usa.
    final usedIds = {
      widget.transaction?.accountId,
      widget.transaction?.destinationAccountId,
    };
    final accounts = allAccounts
        .where((account) => !account.isArchived || usedIds.contains(account.id))
        .toList();

    if (accounts.isEmpty) {
      return StateMessage(
        icon: Icons.account_balance_wallet_outlined,
        text: l10n.transactionsNeedAccountFirst,
        actionLabel: l10n.accountsCreateButton,
        onAction: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(AppRoutes.accounts);
        },
      );
    }

    // Con una sola cuenta no hay nada que elegir.
    if (_accountId == null && accounts.length == 1 && !_isEditing) {
      _accountId = accounts.single.id;
    }

    final categoryType = _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    // Una categoría archivada solo se ofrece si ya es la elegida (al editar).
    final categories = allCategories
        .where(
          (category) =>
              category.type == categoryType &&
              (!category.isArchived || category.id == _categoryId),
        )
        .toList();
    final destinations = accounts
        .where((account) => account.id != _accountId)
        .toList();
    final theme = Theme.of(context);

    DropdownMenuItem<String> accountItem(Account account) => DropdownMenuItem(
      value: account.id,
      child: Text(
        account.isArchived
            ? l10n.accountsArchivedName(account.name)
            : account.name,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              segments: [
                for (final type in [
                  TransactionType.expense,
                  TransactionType.income,
                  TransactionType.transfer,
                ])
                  ButtonSegment(value: type, label: Text(type.label(l10n))),
              ],
              selected: {_type},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => setState(() {
                      _type = selection.first;
                      _categoryId = null;
                      if (!_isTransfer) _destinationId = null;
                    }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (value) => TransactionValidators.amount(l10n, value),
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: l10n.commonAmount,
                hintText: l10n.transactionsAmountHint,
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              isExpanded: true,
              items: [for (final account in accounts) accountItem(account)],
              onChanged: _saving
                  ? null
                  : (id) => setState(() {
                      _accountId = id;
                      if (_destinationId == id) _destinationId = null;
                    }),
              validator: (id) => id == null ? l10n.accountsChoose : null,
              decoration: InputDecoration(
                labelText: _isTransfer
                    ? l10n.transactionsFrom
                    : l10n.commonAccount,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isTransfer)
              DropdownButtonFormField<String>(
                key: ValueKey('destination-$_accountId'),
                initialValue: _destinationId,
                isExpanded: true,
                items: [for (final account in destinations) accountItem(account)],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _destinationId = id),
                validator: (id) => id != null
                    ? null
                    : destinations.isEmpty
                    ? l10n.transactionsNeedAnotherAccount
                    : l10n.transactionsChooseDestination,
                decoration: InputDecoration(
                  labelText: l10n.transactionsTo,
                  border: const OutlineInputBorder(),
                ),
              )
            else
              DropdownButtonFormField<String?>(
                key: ValueKey('category-$_type'),
                initialValue: _categoryId,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.commonNoCategory),
                  ),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(
                        category.isArchived
                            ? l10n.accountsArchivedName(category.name)
                            : category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _categoryId = id),
                decoration: InputDecoration(
                  labelText: l10n.commonCategory,
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.commonDate,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(context.formats.fullDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => TransactionValidators.description(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.transactionsDescriptionLabel,
                hintText: l10n.transactionsDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing
                          ? l10n.commonSaveChanges
                          : l10n.transactionsRecord,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
