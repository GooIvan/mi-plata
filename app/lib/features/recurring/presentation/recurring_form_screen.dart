import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../accounts/presentation/widgets/account_dropdown.dart';
import '../../categories/domain/category.dart';
import '../../categories/domain/category_type.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../currency/domain/currency.dart';
import '../../transactions/domain/transaction_validators.dart';
import '../domain/recurrence.dart';
import '../domain/recurring_draft.dart';
import '../domain/recurring_payment.dart';
import '../domain/recurring_validators.dart';
import 'recurring_error_message.dart';
import 'recurring_providers.dart';
import 'recurring_ui.dart';

/// Abre el formulario para registrar un pago recurrente, o para editar
/// [payment].
Future<void> showRecurringForm(
  BuildContext context, {
  RecurringPayment? payment,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => RecurringFormScreen(payment: payment),
    ),
  );
}

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.payment});

  final RecurringPayment? payment;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.payment?.name);
  final _amount = TextEditingController();
  late String? _accountId = widget.payment?.accountId;
  late String? _categoryId = widget.payment?.categoryId;
  late Recurrence _recurrence =
      widget.payment?.recurrence ?? Recurrence.monthly;
  late DateTime _next = widget.payment?.nextDueDate ?? DateTime.now();
  late DateTime? _end = widget.payment?.endDate;
  bool _saving = false;
  bool _amountReady = false;
  String? _error;

  bool get _isEditing => widget.payment != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_amountReady) {
      _amountReady = true;
      final payment = widget.payment;
      if (payment != null) {
        _amount.text = AmountParser.toInput(payment.amount, context.formats);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, String help) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: help,
  );

  Future<void> _pickNext() async {
    final picked = await _pick(_next, context.l10n.recurringPickNextHelp);
    if (picked != null) setState(() => _next = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(_end ?? _next, context.l10n.recurringPickEndHelp);
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (RecurringValidators.endDate(context.l10n, _end, _next) != null) return;

    final draft = RecurringDraft(
      name: _name.text.trim(),
      amount: AmountParser.parse(_amount.text, context.formats)!,
      accountId: _accountId!,
      categoryId: _categoryId,
      recurrence: _recurrence,
      nextDueDate: _next,
      endDate: _end,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final payments = ref.read(recurringPaymentsProvider.notifier);
    try {
      if (_isEditing) {
        await payments.edit(widget.payment!.id, draft);
      } else {
        await payments.create(draft);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = recurringErrorMessage(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.recurringEdit : l10n.recurringNew),
      ),
      body: switch ((accounts, categories)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          StateMessage(
            icon: Icons.cloud_off_outlined,
            text: recurringErrorMessage(l10n, error),
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
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Una cuenta archivada solo se ofrece si la regla que se edita ya la usa.
    // Las cuotas de una deuda se pagan en la moneda de la deuda, que es la de la
    // cuenta del plan.
    final planCurrency = widget.payment?.isInstallmentPlan == true
        ? allAccounts
              .where((a) => a.id == widget.payment!.accountId)
              .map((a) => a.currency)
              .firstOrNull
        : null;
    final accounts = allAccounts
        .where(
          (a) =>
              (!a.isArchived || a.id == widget.payment?.accountId) &&
              (planCurrency == null || a.currency == planCurrency),
        )
        .toList();
    if (accounts.isEmpty) {
      return StateMessage(
        icon: Icons.account_balance_wallet_outlined,
        text: l10n.transactionsNeedAccountFirst,
        actionLabel: l10n.commonBack,
        onAction: () => Navigator.of(context).pop(),
      );
    }
    // Con una sola cuenta no hay nada que elegir.
    if (_accountId == null && accounts.length == 1) {
      _accountId = accounts.single.id;
    }

    final currency =
        accounts.where((a) => a.id == _accountId).firstOrNull?.currency ??
        defaultCurrency;
    // Solo categorías de gasto; una archivada solo si ya es la elegida.
    final categories = allCategories
        .where(
          (c) =>
              c.type == CategoryType.expense &&
              (!c.isArchived || c.id == _categoryId),
        )
        .toList();
    final frequencies = [
      ...Recurrence.presets,
      if (!Recurrence.presets.contains(_recurrence)) _recurrence,
    ];
    final endError = RecurringValidators.endDate(l10n, _end, _next);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) => RecurringValidators.name(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.recurringNameLabel,
                hintText: l10n.recurringNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (value) => TransactionValidators.amount(l10n, value),
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: l10n.commonAmount,
                hintText: l10n.transactionsAmountHint,
                prefixText: '${currencySymbol(currency)} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AccountDropdown(
              accounts: accounts,
              value: _accountId,
              label: l10n.recurringAccountLabel,
              enabled: !_saving,
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
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
              onChanged: _saving ? null : (id) => setState(() => _categoryId = id),
              decoration: InputDecoration(
                labelText: l10n.commonCategory,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Recurrence>(
              initialValue: _recurrence,
              isExpanded: true,
              items: [
                for (final frequency in frequencies)
                  DropdownMenuItem(
                    value: frequency,
                    child: Text(recurrenceLabel(l10n, frequency)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _recurrence = value);
                    },
              decoration: InputDecoration(
                labelText: l10n.recurringFrequencyLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickNext,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.recurringNextLabel,
                  helperText: l10n.recurringNextHelp,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(context.formats.fullDate(_next)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickEnd,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.recurringEndLabel,
                  border: const OutlineInputBorder(),
                  errorText: endError,
                  suffixIcon: _end == null
                      ? const Icon(Icons.event_outlined)
                      : IconButton(
                          tooltip: l10n.recurringRemoveEnd,
                          icon: const Icon(Icons.close),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _end = null),
                        ),
                ),
                child: Text(
                  _end == null
                      ? l10n.recurringNoEnd
                      : context.formats.fullDate(_end!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.recurringReminderNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
                          : l10n.recurringCreateButton,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
