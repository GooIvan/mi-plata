import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../accounts/presentation/widgets/account_dropdown.dart';
import '../../categories/domain/category.dart';
import '../../categories/domain/category_type.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../recurring/domain/recurrence.dart';
import '../../recurring/presentation/recurring_ui.dart';
import '../../currency/domain/currency.dart';
import '../../currency/presentation/currency_providers.dart';
import '../../currency/presentation/currency_ui.dart';
import '../../transactions/domain/negative_balance_check.dart';
import '../../transactions/domain/transaction_draft.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/domain/transaction_validators.dart';
import '../../transactions/presentation/negative_balance_dialog.dart';
import '../domain/debt.dart';
import '../domain/debt_direction.dart';
import '../domain/debt_draft.dart';
import '../domain/debt_validators.dart';
import '../domain/installment_plan_draft.dart';
import 'debt_error_message.dart';
import 'debt_ui.dart';
import 'debts_providers.dart';

/// Abre el formulario para registrar una deuda nueva (del sentido [direction]),
/// o para editar [debt].
Future<void> showDebtForm(
  BuildContext context, {
  Debt? debt,
  DebtDirection? direction,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => DebtFormScreen(
        debt: debt,
        initialDirection: direction ?? DebtDirection.payable,
      ),
    ),
  );
}

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({
    super.key,
    this.debt,
    this.initialDirection = DebtDirection.payable,
  });

  final Debt? debt;
  final DebtDirection initialDirection;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _counterparty = TextEditingController(
    text: widget.debt?.counterparty,
  );
  final _amount = TextEditingController();
  late final _notes = TextEditingController(text: widget.debt?.notes);
  late DebtDirection _direction =
      widget.debt?.direction ?? widget.initialDirection;
  late DateTime _start = widget.debt?.startDate ?? DateTime.now();
  late DateTime? _due = widget.debt?.dueDate;
  bool _registerMoney = false;
  String? _accountId;

  // Una compra a cuotas: la deuda y un plan de pagos.
  bool _installments = false;
  final _count = TextEditingController();
  final _installmentAmount = TextEditingController();
  bool _installmentAmountEdited = false;
  Recurrence _recurrence = Recurrence.monthly;
  late DateTime _firstDue = Recurrence.monthly.advance(
    _start,
    anchorDay: _start.day,
  );
  String? _planAccountId;
  String? _planCategoryId;

  /// La moneda elegida para una deuda sin cuenta; null es la moneda base.
  String? _currency;
  bool _saving = false;
  bool _amountReady = false;
  String? _error;

  bool get _isEditing => widget.debt != null;
  bool get _isPayable => _direction == DebtDirection.payable;

  /// Si se está armando un plan de cuotas (solo al crear una deuda que debo).
  bool get _isPlan => _installments && !_isEditing && _isPayable;

  /// La moneda de la deuda según lo que se eligió: la de la cuenta si el dinero
  /// se registra en una; si no, la que se escogió (o la moneda base).
  String _currencyFor(List<Account> accounts) {
    if (_isEditing) return widget.debt!.currency;
    // En cuotas, la deuda es en la moneda de la cuenta con la que se paga.
    if (_isPlan) {
      final account = accounts.where((a) => a.id == _planAccountId).firstOrNull;
      if (account != null) return account.currency;
    }
    if (_registerMoney) {
      final account = accounts.where((a) => a.id == _accountId).firstOrNull;
      if (account != null) return account.currency;
    }
    return _currency ??
        ref.read(currencyConverterProvider).value?.base ??
        defaultCurrency;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_amountReady) {
      _amountReady = true;
      final debt = widget.debt;
      if (debt != null) {
        _amount.text = AmountParser.toInput(debt.amount, context.formats);
      }
    }
  }

  @override
  void dispose() {
    _counterparty.dispose();
    _count.dispose();
    _installmentAmount.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, String help) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: help,
  );

  Future<void> _pickStart() async {
    final picked = await _pick(_start, context.l10n.debtsPickStartHelp);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickDue() async {
    final picked = await _pick(_due ?? _start, context.l10n.debtsPickDueHelp);
    if (picked != null) setState(() => _due = picked);
  }

  String? _amountError(String? value) {
    final l10n = context.l10n;
    final error = DebtValidators.amount(l10n, value);
    if (error != null) return error;

    final formats = context.formats;
    final paid = widget.debt?.paid ?? 0;
    final cents = (double.parse(AmountParser.parse(value, formats)!) * 100)
        .round();
    if (paid > 0 && cents < (paid * 100).round()) {
      return l10n.debtsAmountBelowPaid(
        formats.money(paid, currency: widget.debt!.currency),
      );
    }
    return null;
  }

  /// Propone el valor de la cuota (el total entre las cuotas, redondeado hacia
  /// arriba al centavo: la última cuota queda un poco menor) mientras no se
  /// haya escrito otro.
  void _suggestInstallmentAmount() {
    if (_installmentAmountEdited) return;
    final formats = context.formats;
    final total = AmountParser.parse(_amount.text, formats);
    final count = int.tryParse(_count.text.trim());
    if (total == null || count == null || count < 1) return;

    final cents = (double.parse(total) * 100).round();
    if (cents <= 0) return;
    _installmentAmount.text = AmountParser.toInput(
      (cents / count).ceil() / 100,
      formats,
    );
  }

  Future<DateTime?> _pickFirstDue() => _pick(_firstDue, context.l10n.debtsInstallmentsFirstHelp);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPlan && DebtValidators.dueDate(context.l10n, _due, _start) != null) {
      return;
    }

    final counterparty = _counterparty.text.trim();
    final amount = AmountParser.parse(_amount.text, context.formats)!;
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final debts = ref.read(debtsProvider.notifier);

    if (_isPlan) {
      setState(() {
        _saving = true;
        _error = null;
      });
      await _run(
        () => debts.createWithInstallments(
          InstallmentPlanDraft(
            counterparty: counterparty,
            amount: amount,
            installments: int.parse(_count.text.trim()),
            installmentAmount: AmountParser.parse(
              _installmentAmount.text,
              context.formats,
            )!,
            recurrence: _recurrence,
            firstDue: _firstDue,
            accountId: _planAccountId!,
            categoryId: _planCategoryId,
            startDate: _start,
            notes: notes,
          ),
        ),
      );
      return;
    }

    if (!_isEditing) {
      final draft = DebtDraft(
        direction: _direction,
        counterparty: counterparty,
        amount: amount,
        startDate: _start,
        dueDate: _due,
        notes: notes,
        accountId: _registerMoney ? _accountId : null,
        // Con cuenta, la deuda es en la moneda de la cuenta.
        currency: _registerMoney
            ? null
            : _currencyFor(ref.read(accountsProvider).value ?? const []),
        description: _isPayable
            ? context.l10n.debtsLoanDescriptionPayable(counterparty)
            : context.l10n.debtsLoanDescriptionReceivable(counterparty),
      );

      // Si presté dinero, sale de la cuenta: se avisa si la deja en negativo.
      if (draft.accountId != null && !_isPayable) {
        final warnings = NegativeBalanceCheck.after(
          accounts: ref.read(accountsProvider).value ?? const <Account>[],
          draft: TransactionDraft(
            type: TransactionType.expense,
            accountId: draft.accountId!,
            amount: amount,
            date: _start,
          ),
        );
        if (warnings.isNotEmpty &&
            !await confirmNegativeBalance(
              context,
              warnings,
              title: context.l10n.negativeBalanceRecordTitle,
              confirmLabel: context.l10n.negativeBalanceRecordAnyway,
            )) {
          return;
        }
        if (!mounted) return;
      }

      setState(() {
        _saving = true;
        _error = null;
      });
      await _run(() => debts.create(draft));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await _run(
      () => debts.edit(
        widget.debt!.id,
        counterparty: counterparty,
        amount: amount,
        dueDate: _due,
        notes: notes,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = debtErrorMessage(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dueError = DebtValidators.dueDate(l10n, _due, _start);
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((account) => !account.isArchived)
        .toList();
    if (_registerMoney && _accountId == null && accounts.length == 1) {
      _accountId = accounts.single.id;
    }
    // Con una sola cuenta no hay nada que elegir al armar las cuotas.
    if (_isPlan && _planAccountId == null && accounts.length == 1) {
      _planAccountId = accounts.single.id;
    }
    final currency = _currencyFor(accounts);
    final planCategories =
        (ref.watch(categoriesProvider).value ?? const <Category>[])
            .where((c) => c.type == CategoryType.expense && !c.isArchived)
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.debtsEdit : l10n.debtsNew)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<DebtDirection>(
                showSelectedIcon: false,
                segments: [
                  for (final direction in DebtDirection.values)
                    ButtonSegment(
                      value: direction,
                      label: Text(direction.label(l10n)),
                    ),
                ],
                selected: {_direction},
                onSelectionChanged: _isEditing || _saving
                    ? null
                    : (selection) => setState(() => _direction = selection.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _counterparty,
                enabled: !_saving,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => DebtValidators.counterparty(l10n, value),
                decoration: InputDecoration(
                  labelText: _isPayable
                      ? l10n.debtsCounterpartyPayable
                      : l10n.debtsCounterpartyReceivable,
                  hintText: l10n.debtsCounterpartyHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isEditing && !_registerMoney && !_isPlan) ...[
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  isExpanded: true,
                  items: [
                    for (final option in supportedCurrencies)
                      DropdownMenuItem(
                        value: option.code,
                        child: Text(
                          currencyOptionLabel(l10n, option.code),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (code) => setState(() => _currency = code),
                  decoration: InputDecoration(
                    labelText: l10n.currencyLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: _amountError,
                onChanged: _isPlan
                    ? (_) => setState(_suggestInstallmentAmount)
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.debtsAmountLabel,
                  hintText: l10n.debtsAmountHint,
                  prefixText: '${currencySymbol(currency)} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _isEditing || _saving ? null : _pickStart,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.debtsStartLabel,
                    border: const OutlineInputBorder(),
                    enabled: !_isEditing,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(context.formats.fullDate(_start)),
                ),
              ),
              if (!_isPlan) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _saving ? null : _pickDue,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.debtsDueLabel,
                      border: const OutlineInputBorder(),
                      errorText: dueError,
                      suffixIcon: _due == null
                          ? const Icon(Icons.event_outlined)
                          : IconButton(
                              tooltip: l10n.debtsRemoveDue,
                              icon: const Icon(Icons.close),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _due = null),
                            ),
                    ),
                    child: Text(
                      _due == null
                          ? l10n.debtsNoDate
                          : context.formats.fullDate(_due!),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                enabled: !_saving,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => DebtValidators.notes(l10n, value),
                decoration: InputDecoration(
                  labelText: l10n.debtsNotesLabel,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!_isEditing && _isPayable) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.debtsInstallmentsSwitch),
                  subtitle: Text(
                    accounts.isEmpty
                        ? l10n.debtsRegisterMoneyNeedAccount
                        : l10n.debtsInstallmentsSwitchHelp,
                  ),
                  value: _installments,
                  onChanged: accounts.isEmpty || _saving
                      ? null
                      : (value) => setState(() {
                          _installments = value;
                          if (value) _registerMoney = false;
                          _suggestInstallmentAmount();
                        }),
                ),
              ],
              if (_isPlan) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _count,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    return count == null || count < 1 || count > 360
                        ? l10n.debtsInstallmentsCountInvalid
                        : null;
                  },
                  onChanged: (_) => setState(_suggestInstallmentAmount),
                  decoration: InputDecoration(
                    labelText: l10n.debtsInstallmentsCount,
                    hintText: l10n.debtsInstallmentsCountHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _installmentAmount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => TransactionValidators.amount(l10n, value),
                  onChanged: (_) => _installmentAmountEdited = true,
                  decoration: InputDecoration(
                    labelText: l10n.debtsInstallmentsAmount,
                    helperText: l10n.debtsInstallmentsAmountHelp,
                    helperMaxLines: 2,
                    hintText: l10n.debtsAmountHint,
                    prefixText: '${currencySymbol(currency)} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Recurrence>(
                  initialValue: _recurrence,
                  isExpanded: true,
                  items: [
                    for (final frequency in Recurrence.presets)
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
                    labelText: l10n.debtsInstallmentsFrequency,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          final picked = await _pickFirstDue();
                          if (picked != null) setState(() => _firstDue = picked);
                        },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.debtsInstallmentsFirst,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(context.formats.fullDate(_firstDue)),
                  ),
                ),
                const SizedBox(height: 16),
                AccountDropdown(
                  accounts: accounts,
                  value: _planAccountId,
                  label: l10n.debtsInstallmentsPayFrom,
                  enabled: !_saving,
                  onChanged: (id) => setState(() => _planAccountId = id),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _planCategoryId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.commonNoCategory),
                    ),
                    for (final category in planCategories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _planCategoryId = id),
                  decoration: InputDecoration(
                    labelText: l10n.commonCategory,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
              ],
              if (!_isEditing && !_isPlan) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.debtsRegisterMoney),
                  subtitle: Text(
                    accounts.isEmpty
                        ? l10n.debtsRegisterMoneyNeedAccount
                        : _isPayable
                        ? l10n.debtsRegisterMoneyPayable
                        : l10n.debtsRegisterMoneyReceivable,
                  ),
                  value: _registerMoney,
                  onChanged: accounts.isEmpty || _saving
                      ? null
                      : (value) => setState(() => _registerMoney = value),
                ),
                if (_registerMoney) ...[
                  const SizedBox(height: 8),
                  AccountDropdown(
                    accounts: accounts,
                    value: _accountId,
                    label: _isPayable ? l10n.debtsReceiveIn : l10n.debtsTakeFrom,
                    enabled: !_saving,
                    onChanged: (id) => setState(() => _accountId = id),
                  ),
                ],
              ],
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
                        _isEditing ? l10n.commonSaveChanges : l10n.debtsCreate,
                      ),
              ),
              if (_isEditing && (widget.debt?.paid ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.debtsLockedNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
