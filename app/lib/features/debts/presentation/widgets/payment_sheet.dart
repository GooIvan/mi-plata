import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/error_banner.dart';
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
      helpText: 'Fecha del abono',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = AmountParser.parse(_amount.text)!;

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
            title: '¿Registrar de todos modos?',
            confirmLabel: 'Registrar igual',
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
            description: description.isEmpty ? null : description,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = debtErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  ? 'Abonar a ${debt.counterparty}'
                  : 'Abono de ${debt.counterparty}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Pendiente: ${formatMoney(debt.remaining, currency: debt.currency)}',
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
              validator: (value) =>
                  DebtValidators.paymentAmount(value, remaining: debt.remaining),
              decoration: InputDecoration(
                labelText: 'Monto del abono',
                hintText: 'Ej: 100.000',
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: _saving
                      ? null
                      : () => _amount.text = AmountParser.toInput(debt.remaining),
                  child: Text(_isPayable ? 'Pagar todo' : 'Cobrar todo'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              Text(
                'Primero crea una cuenta en ${debt.currency} para registrar el abono.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              AccountDropdown(
                accounts: accounts,
                value: _accountId,
                label: _isPayable ? 'Pagar desde' : 'Recibir en',
                enabled: !_saving,
                onChanged: (id) => setState(() => _accountId = id),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(formatFullDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value?.trim().length ?? 0) > 200
                  ? 'Usa 200 caracteres o menos'
                  : null,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: _isPayable
                    ? 'Abono a ${debt.counterparty}'
                    : 'Abono de ${debt.counterparty}',
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
                  : const Text('Registrar abono'),
            ),
          ],
        ),
      ),
    );
  }
}
