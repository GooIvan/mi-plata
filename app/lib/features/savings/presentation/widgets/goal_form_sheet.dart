import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/account_type.dart';
import '../../../accounts/domain/amount_parser.dart';
import '../../../accounts/presentation/account_label.dart';
import '../../../accounts/presentation/accounts_providers.dart';
import '../../../accounts/presentation/widgets/account_form_sheet.dart';
import '../../../currency/domain/currency.dart';
import '../../../currency/presentation/currency_providers.dart';
import '../../domain/goal_draft.dart';
import '../../domain/goal_validators.dart';
import '../../domain/savings_goal.dart';
import '../goal_error_message.dart';
import '../goals_providers.dart';

/// Abre el formulario para crear una meta, o para editar [goal].
Future<void> showGoalForm(BuildContext context, {SavingsGoal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GoalFormSheet(goal: goal),
  );
}

class GoalFormSheet extends ConsumerStatefulWidget {
  const GoalFormSheet({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.goal?.name);
  final _target = TextEditingController();
  late String? _accountId = widget.goal?.accountId;
  late DateTime? _date = widget.goal?.targetDate;
  bool _saving = false;
  bool _targetReady = false;
  String? _error;

  bool get _isEditing => widget.goal != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_targetReady) {
      _targetReady = true;
      final goal = widget.goal;
      if (goal != null) {
        _target.text = AmountParser.toInput(
          goal.targetCents / 100,
          context.formats,
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Las cuentas donde se puede ahorrar: no archivadas, que no sean tarjetas y
  /// que no tengan ya otra meta activa.
  List<Account> _eligible(List<Account> accounts, List<SavingsGoal> goals) {
    final taken = {
      for (final goal in goals)
        if (!goal.isArchived) goal.accountId,
    };
    return [
      for (final account in accounts)
        if (!account.isArchived &&
            account.type != AccountType.card &&
            !taken.contains(account.id))
          account,
    ];
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Abre el formulario de cuentas y, si se creó una que sirve, la elige.
  Future<void> _createAccount() async {
    final before = {
      for (final account
          in ref.read(accountsProvider).value ?? const <Account>[])
        account.id,
    };
    await showAccountForm(context);
    if (!mounted) return;

    final accounts = await ref.read(accountsProvider.future);
    final created = accounts
        .where(
          (account) =>
              !before.contains(account.id) &&
              !account.isArchived &&
              account.type != AccountType.card,
        )
        .firstOrNull;
    if (created != null && mounted) setState(() => _accountId = created.id);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    if (_accountId == null) {
      // Con selector, su validador ya lo reclamó; sin una cuenta libre no hay
      // selector, y se avisa aquí.
      final eligible = _eligible(
        ref.read(accountsProvider).value ?? const <Account>[],
        ref.read(savingsGoalsProvider).value ?? const <SavingsGoal>[],
      );
      if (eligible.isEmpty) {
        setState(() => _error = context.l10n.goalsAccountRequired);
      }
      return;
    }
    if (!valid) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final goals = ref.read(savingsGoalsProvider.notifier);
    final draft = GoalDraft(
      name: _name.text,
      targetAmount: AmountParser.parse(_target.text, context.formats)!,
      accountId: _accountId!,
      targetDate: _date,
    );

    try {
      if (_isEditing) {
        await goals.edit(widget.goal!.id, draft);
      } else {
        await goals.create(draft);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = goalErrorMessage(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final formats = context.formats;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final goals =
        ref.watch(savingsGoalsProvider).value ?? const <SavingsGoal>[];
    final base = ref.watch(currencyConverterProvider).value?.base;

    final eligible = _eligible(accounts, goals);
    final chosen = accounts.where((a) => a.id == _accountId).firstOrNull;
    final currency = chosen?.currency ?? base ?? defaultCurrency;

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
              _isEditing ? l10n.goalsEdit : l10n.goalsNew,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) => GoalValidators.name(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.goalsNameLabel,
                hintText: l10n.goalsNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.goalsAccountLabel,
                  helperText: l10n.goalsAccountLocked,
                  border: const OutlineInputBorder(),
                  enabled: false,
                ),
                child: Text(
                  chosen == null
                      ? l10n.commonAccount
                      : accountLabel(l10n, chosen, baseCurrency: base),
                ),
              )
            else if (eligible.isEmpty)
              Text(
                l10n.goalsNoFreeAccount,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('goal-account-$_accountId'),
                initialValue: eligible.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                isExpanded: true,
                items: [
                  for (final account in eligible)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        accountLabel(l10n, account, baseCurrency: base),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _accountId = id),
                validator: (id) =>
                    id == null ? l10n.goalsAccountRequired : null,
                decoration: InputDecoration(
                  labelText: l10n.goalsAccountLabel,
                  helperText: l10n.goalsAccountHelp,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (!_isEditing)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _createAccount,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.goalsNewAccount),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _target,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              validator: (value) => GoalValidators.target(l10n, value),
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.goalsTargetLabel,
                prefixText: '${currencySymbol(currency)} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.goalsDeadlineLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: _date == null
                      ? const Icon(Icons.event_outlined)
                      : IconButton(
                          tooltip: l10n.goalsDeadlineClear,
                          icon: const Icon(Icons.close),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _date = null),
                        ),
                ),
                child: Text(
                  _date == null
                      ? l10n.goalsDeadlineNone
                      : formats.fullDate(_date!),
                ),
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
                  : Text(_isEditing ? l10n.commonSave : l10n.goalsCreateButton),
            ),
          ],
        ),
      ),
    );
  }
}
