import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/amount_parser.dart';
import '../../../accounts/presentation/accounts_providers.dart';
import '../../../accounts/presentation/widgets/account_dropdown.dart';
import '../../../transactions/domain/negative_balance_check.dart';
import '../../../transactions/domain/transaction_draft.dart';
import '../../../transactions/domain/transaction_type.dart';
import '../../../transactions/presentation/negative_balance_dialog.dart';
import '../../domain/debt.dart';
import '../../domain/debt_direction.dart';
import '../../../transactions/domain/transaction_validators.dart';
import '../../domain/debt_validators.dart';
import '../debt_error_message.dart';
import '../debts_providers.dart';

/// Abre la hoja para registrar un abono a [debt].
Future<void> showPaymentSheet(BuildContext context, Debt debt) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PaymentSheet(debt: debt),
  );
}

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  bool get _isPayable => widget.debt.direction == DebtDirection.payable;

  /// Cómo se llama el movimiento si no se escribe una descripción: en el
  /// idioma del usuario, no en el de la base.
  String get _defaultDescription => _isPayable
      ? context.l10n.debtsPaymentDescriptionPayable(widget.debt.counterparty)
      : context.l10n.debtsPaymentDescriptionReceivable(
          widget.debt.counterparty,
        );

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
      helpText: context.l10n.debtsPaymentDateHelp,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = AmountParser.parse(_amount.text, context.formats)!;

    // Si yo pago, el dinero sale de la cuenta: se avisa si la deja en negativo.
    if (_isPayable) {
      final warnings = NegativeBalanceCheck.after(
        accounts: ref.read(accountsProvider).value ?? const <Account>[],
        draft: TransactionDraft(
          type: TransactionType.expense,
          accountId: _accountId!,
          amount: amount,
          date: _date,
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

    final description = _description.text.trim();
    try {
      await ref
          .read(debtsProvider.notifier)
          .registerPayment(
            debtId: widget.debt.id,
            accountId: _accountId!,
            amount: amount,
            date: _date,
            description: description.isEmpty ? _defaultDescription : description,
          );
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
    final formats = context.formats;
    final debt = widget.debt;

    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((account) => !account.isArchived && account.currency == debt.currency)
        .toList();
    // Con una sola cuenta no hay nada que elegir.
    if (_accountId == null && accounts.length == 1) {
      _accountId = accounts.single.id;
    }

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
              _isPayable
                  ? l10n.debtsPaySheetTitlePayable(debt.counterparty)
                  : l10n.debtsPaymentDescriptionReceivable(debt.counterparty),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.debtsPendingAmount(
                formats.money(debt.remaining, currency: debt.currency),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (value) => DebtValidators.paymentAmount(
                l10n,
                value,
                remaining: debt.remaining,
              ),
              decoration: InputDecoration(
                labelText: l10n.debtsPaymentAmountLabel,
                hintText: l10n.debtsPaymentAmountHint,
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: _saving
                      ? null
                      : () => _amount.text = AmountParser.toInput(
                          debt.remaining,
                          formats,
                        ),
                  child: Text(
                    _isPayable ? l10n.debtsPayAll : l10n.debtsCollectAll,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              Text(
                l10n.debtsNeedCurrencyAccount(debt.currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              AccountDropdown(
                accounts: accounts,
                value: _accountId,
                label: _isPayable ? l10n.debtsPayFrom : l10n.debtsReceiveIn,
                enabled: !_saving,
                onChanged: (id) => setState(() => _accountId = id),
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
                child: Text(formats.fullDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  TransactionValidators.description(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.transactionsDescriptionLabel,
                hintText: _isPayable
                    ? l10n.debtsPaymentDescriptionPayable(debt.counterparty)
                    : l10n.debtsPaymentDescriptionReceivable(debt.counterparty),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || accounts.isEmpty ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.debtsRecordPayment),
            ),
          ],
        ),
      ),
    );
  }
}
